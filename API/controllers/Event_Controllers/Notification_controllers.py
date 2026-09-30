import asyncio
import json
from collections import defaultdict
from typing import Dict, Set

import pymysql
from fastapi import HTTPException, status, Depends
from fastapi.responses import StreamingResponse
from DB.DBConnect import getConnect
from models.schema import AddNotificationRequest
from auth.dependencies import get_current_account

# NotificationType values used by the app's icon/colour mapping:
#   order  - ticket / payment related
#   event  - event reminders ("starts soon", "new event")
#   wish   - wish list related
#   promo  - promotions / sales
#   system - app / account related


def _account_ids_by_status(status_ids) -> list:
    """AccountIDs of every account whose StatusID is in status_ids."""
    con = getConnect()
    try:
        with con.cursor() as cur:
            placeholders = ", ".join(["%s"] * len(status_ids))
            cur.execute(
                f"SELECT AccountID FROM accountinfo WHERE StatusID IN ({placeholders})",
                list(status_ids),
            )
            return [row["AccountID"] for row in cur.fetchall()]
    except pymysql.MySQLError:
        return []
    finally:
        con.close()


def employee_account_ids() -> list:
    """AccountIDs of every EMPLOYEE (StatusID 4) account."""
    return _account_ids_by_status([4])


def staff_account_ids() -> list:
    """AccountIDs of every EMPLOYEE (4) and SUPERADMIN (3) account."""
    return _account_ids_by_status([3, 4])


# ---------------------------------------------------------------------------
# Live push
#
# Every open /notification/stream connection registers an asyncio.Event under
# its account id. Whenever a notification row is inserted for that account we
# set the event, so the stream wakes up and pushes it to the phone within a few
# milliseconds instead of waiting for the next database check.
#
# The events live in this process's memory. If you run several uvicorn
# workers, a worker that did not insert the row still delivers it, just via the
# stream's fallback database check (STREAM_FALLBACK_SECONDS) instead of instantly.
# ---------------------------------------------------------------------------
STREAM_FALLBACK_SECONDS = 2

_wakeups: Dict[int, Set[asyncio.Event]] = defaultdict(set)
_stream_loop = None  # event loop the streams run on (set by the first stream)


def _wake_streams(account_ids) -> None:
    """Wake every open stream that belongs to one of these accounts.
    Safe to call from any thread and when no stream is open."""
    loop = _stream_loop
    if loop is None or loop.is_closed():
        return
    ids = set(account_ids)

    def _set() -> None:
        for account_id in ids:
            for event in list(_wakeups.get(account_id, ())):
                event.set()

    try:
        loop.call_soon_threadsafe(_set)
    except RuntimeError:
        pass


def notify_accounts(recipient_ids, notification_type: str, title: str, body: str, link: str = None) -> None:
    """
    Inserts one notification row per recipient and pushes it live to any
    device that account has open. `link` is an optional app deep-link payload:
        "event:<EventID>"      -> opens that event's detail page
        "org_invite:<MemberID>" -> opens the organizer invite page
    Best-effort: failures are swallowed so a notification problem never breaks
    the caller's flow.
    """
    if not recipient_ids:
        return
    recipients = set(recipient_ids)
    con = getConnect()
    try:
        with con.cursor() as cur:
            for account_id in recipients:
                cur.execute(
                    """
                    INSERT INTO notificationinfo (AccountID, NotificationType, Title, Body, Link)
                    VALUES (%s, %s, %s, %s, %s)
                    """,
                    (account_id, notification_type, title, body, link),
                )
        con.commit()
        _wake_streams(recipients)
    except pymysql.MySQLError:
        pass
    finally:
        con.close()


def _json_default(value):
    return value.isoformat() if hasattr(value, "isoformat") else str(value)


def _read_stream_state(con, account_id: int, last_id: int):
    """One cheap check: (unread count, highest NotificationID, rows newer than last_id)."""
    with con.cursor() as cur:
        cur.execute(
            "SELECT COUNT(*) AS c FROM notificationinfo WHERE AccountID = %s AND IsRead = 0",
            (account_id,),
        )
        unread = cur.fetchone()["c"]
        cur.execute(
            "SELECT COALESCE(MAX(NotificationID), 0) AS m FROM notificationinfo WHERE AccountID = %s",
            (account_id,),
        )
        newest = cur.fetchone()["m"]
        fresh = []
        if newest > last_id:
            cur.execute(
                """
                SELECT * FROM notificationinfo
                WHERE AccountID = %s AND NotificationID > %s
                ORDER BY NotificationID ASC
                LIMIT 50
                """,
                (account_id, last_id),
            )
            fresh = cur.fetchall()
    return unread, newest, fresh


async def stream_notifications(current=Depends(get_current_account)):
    """
    Server-Sent Events endpoint -- the live channel behind the home bell badge
    and the bottom-nav badge.

    Every event is one JSON line:
        data: {"UnreadCount": 3, "New": [ {..notification row..}, ... ]}

    * "New" holds notifications created since the last event, so the app can
      show them instantly without another HTTP request.
    * "UnreadCount" is always the current total, so the app can also notice
      notifications that were read on another device.
    The first event after connecting has an empty "New" list (it only tells the
    app the current unread count). A keep-alive comment is sent when idle so
    proxies don't close the connection.
    """
    global _stream_loop
    account_id = current["account_id"]
    loop = asyncio.get_running_loop()
    _stream_loop = loop

    async def event_stream():
        wakeup = asyncio.Event()
        _wakeups[account_id].add(wakeup)
        con = None
        last_id = None
        last_unread = -1
        try:
            while True:
                try:
                    if con is None:
                        con = getConnect()
                        # IMPORTANT: this connection stays open for the whole
                        # stream. Without autocommit MySQL keeps one snapshot
                        # (REPEATABLE READ) for the connection's lifetime, so
                        # rows inserted later would never be seen.
                        con.autocommit(True)
                    unread, newest, fresh = await asyncio.to_thread(
                        _read_stream_state,
                        con,
                        account_id,
                        last_id if last_id is not None else 2**62,
                    )
                except pymysql.MySQLError:
                    if con is not None:
                        try:
                            con.close()
                        except Exception:
                            pass
                    con = None
                    await asyncio.sleep(STREAM_FALLBACK_SECONDS)
                    continue

                if last_id is None:
                    # First check after connecting: report the count only;
                    # anything already in the table is "old", not "new".
                    last_id = newest
                    last_unread = unread
                    payload = {"UnreadCount": unread, "New": []}
                    yield f"data: {json.dumps(payload)}\n\n"
                elif fresh or unread != last_unread:
                    last_id = max(last_id, newest)
                    last_unread = unread
                    payload = {"UnreadCount": unread, "New": fresh}
                    yield f"data: {json.dumps(payload, default=_json_default)}\n\n"
                else:
                    yield ": keep-alive\n\n"

                # Sleep until a notification is inserted (instant wake-up) or
                # the fallback interval passes (covers other workers).
                try:
                    await asyncio.wait_for(wakeup.wait(), STREAM_FALLBACK_SECONDS)
                except asyncio.TimeoutError:
                    pass
                wakeup.clear()
        except asyncio.CancelledError:
            pass
        finally:
            sockets = _wakeups.get(account_id)
            if sockets is not None:
                sockets.discard(wakeup)
                if not sockets:
                    _wakeups.pop(account_id, None)
            if con is not None:
                try:
                    con.close()
                except Exception:
                    pass

    return StreamingResponse(
        event_stream(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


async def create_notification(req_data: AddNotificationRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                INSERT INTO notificationinfo
                (AccountID, NotificationType, Title, Body, Link)
                VALUES (%s, %s, %s, %s, %s)
            """
            cur.execute(sql, (
                req_data.AccountID,
                req_data.NotificationType,
                req_data.Title,
                req_data.Body,
                req_data.Link,
            ))
            con.commit()
            notification_id = cur.lastrowid

        _wake_streams([req_data.AccountID])
        return {"msg": "Notification created successfully", "NotificationID": notification_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_notifications_by_account(account_id: int):
    """Newest-first notifications for one account."""
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                SELECT * FROM notificationinfo
                WHERE AccountID = %s
                ORDER BY CreatedAtYMDT DESC, NotificationID DESC
            """
            cur.execute(sql, (account_id,))
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_unread_count(account_id: int):
    """
    Number of unread notifications for one account -- drives the bell badge
    on the home page and the drawer badge.
    """
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute(
                "SELECT COUNT(*) AS c FROM notificationinfo WHERE AccountID = %s AND IsRead = 0",
                (account_id,),
            )
            row = cur.fetchone()

        return {"AccountID": account_id, "UnreadCount": row["c"]}

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def mark_notification_read(notification_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute(
                "UPDATE notificationinfo SET IsRead = 1 WHERE NotificationID = %s",
                (notification_id,),
            )
            con.commit()

        return {"msg": "Notification marked as read", "NotificationID": notification_id}

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def mark_all_read(account_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute(
                "UPDATE notificationinfo SET IsRead = 1 WHERE AccountID = %s AND IsRead = 0",
                (account_id,),
            )
            rows_updated = cur.rowcount
            con.commit()

        return {"msg": "All notifications marked as read", "UpdatedCount": rows_updated}

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def generate_for_account(account_id: int):
    """
    Builds real notifications for an account from the actual data: ticket
    orders (order), wish-listed events starting within a week (event), and
    new/upcoming events from organizers the account follows (event).

    The account is reminded again on the day before an event it has tickets
    for (type "event", title "... is tomorrow").

    Notification titles are deduplicated per account so re-generating never
    spams the list.
    """
    try:
        con = getConnect()
        created = 0
        with con.cursor() as cur:
            def insert_notification(ntype, title, body, link=None):
                nonlocal created
                cur.execute(
                    "SELECT COUNT(*) AS c FROM notificationinfo WHERE AccountID = %s AND Title = %s",
                    (account_id, title),
                )
                if cur.fetchone()["c"] > 0:
                    # Already sent. Older rows were created before links existed,
                    # so give them their event link now (never overwrite one).
                    if link:
                        cur.execute(
                            """
                            UPDATE notificationinfo SET Link = %s
                            WHERE AccountID = %s AND Title = %s
                              AND (Link IS NULL OR Link = '')
                            """,
                            (link, account_id, title),
                        )
                    return
                cur.execute(
                    "INSERT INTO notificationinfo (AccountID, NotificationType, Title, Body, Link) VALUES (%s, %s, %s, %s, %s)",
                    (account_id, ntype, title, body, link),
                )
                created += 1

            def pretty_start(dt):
                return dt.strftime("%B %d, %H:%M") if dt else "soon"

            def pretty_time(dt):
                return dt.strftime("%H:%M") if dt else "early"

            # Orders the account already paid for -> ticket confirmed.
            cur.execute("""
                SELECT DISTINCT e.EventID, e.EventName, e.EventStartingYMDT, e.EventAddress
                FROM ordersinfo o
                JOIN ticketattendence ta ON ta.OrderID = o.OrderID
                JOIN tickettype t ON t.TicketTypeID = ta.TicketTypeID
                JOIN eventinfo e ON e.EventID = t.EventID
                WHERE o.AccountID = %s
            """, (account_id,))
            for row in cur.fetchall():
                start = pretty_start(row["EventStartingYMDT"])
                insert_notification(
                    "order",
                    f"Ticket confirmed for {row['EventName']}",
                    f"Your order for {row['EventName']} has been confirmed. The event starts on {start} at {row['EventAddress']}. Show the QR code at the entrance to check in.",
                    f"event:{row['EventID']}",
                )

            # Events with a ticket start tomorrow -> "it's tomorrow" reminder.
            cur.execute("""
                SELECT DISTINCT e.EventID, e.EventName, e.EventStartingYMDT, e.EventAddress
                FROM ordersinfo o
                JOIN ticketattendence ta ON ta.OrderID = o.OrderID
                JOIN tickettype t ON t.TicketTypeID = ta.TicketTypeID
                JOIN eventinfo e ON e.EventID = t.EventID
                WHERE o.AccountID = %s
                  AND e.EventStartingYMDT >= DATE_ADD(CURDATE(), INTERVAL 1 DAY)
                  AND e.EventStartingYMDT < DATE_ADD(CURDATE(), INTERVAL 2 DAY)
            """, (account_id,))
            for row in cur.fetchall():
                time = pretty_time(row["EventStartingYMDT"])
                insert_notification(
                    "event",
                    f"{row['EventName']} is tomorrow",
                    f"Don't forget, {row['EventName']} starts tomorrow at {time} at {row['EventAddress']}.",
                    f"event:{row['EventID']}",
                )

            # Wish-listed events starting tomorrow -> same reminder.
            cur.execute("""
                SELECT e.EventID, e.EventName, e.EventStartingYMDT, e.EventAddress
                FROM wishlistinfo w
                JOIN eventinfo e ON e.EventID = w.EventID
                WHERE w.AccountID = %s
                  AND e.EventStartingYMDT >= DATE_ADD(CURDATE(), INTERVAL 1 DAY)
                  AND e.EventStartingYMDT < DATE_ADD(CURDATE(), INTERVAL 2 DAY)
            """, (account_id,))
            for row in cur.fetchall():
                time = pretty_time(row["EventStartingYMDT"])
                insert_notification(
                    "event",
                    f"{row['EventName']} is tomorrow",
                    f"{row['EventName']} starts tomorrow at {time} at {row['EventAddress']}. Don't miss it!",
                    f"event:{row['EventID']}",
                )

            # Wish-listed events starting within the next 7 days.
            cur.execute("""
                SELECT e.EventID, e.EventName, e.EventStartingYMDT, e.EventAddress
                FROM wishlistinfo w
                JOIN eventinfo e ON e.EventID = w.EventID
                WHERE w.AccountID = %s
                  AND e.EventStartingYMDT BETWEEN NOW() AND DATE_ADD(NOW(), INTERVAL 7 DAY)
            """, (account_id,))
            for row in cur.fetchall():
                start = pretty_start(row["EventStartingYMDT"])
                insert_notification(
                    "event",
                    f"{row['EventName']} starts soon",
                    f"{row['EventName']} starts on {start} at {row['EventAddress']}. Don't miss it!",
                    f"event:{row['EventID']}",
                )

            # Upcoming events from organizers the account follows.
            cur.execute("""
                SELECT e.EventID, e.EventName, e.EventStartingYMDT, e.EventAddress
                FROM followinfo f
                JOIN eventinfo e ON e.EventOrganizerID = f.EventOrganizerID
                WHERE f.AccountID = %s
                  AND e.EventStartingYMDT > NOW()
                ORDER BY e.EventStartingYMDT
                LIMIT 5
            """, (account_id,))
            for row in cur.fetchall():
                start = pretty_start(row["EventStartingYMDT"])
                insert_notification(
                    "event",
                    f"New event: {row['EventName']}",
                    f"An organizer you follow added {row['EventName']} on {start} at {row['EventAddress']}.",
                    f"event:{row['EventID']}",
                )

            # Welcome message the first time the account gets notifications.
            cur.execute(
                "SELECT COUNT(*) AS c FROM notificationinfo WHERE AccountID = %s",
                (account_id,),
            )
            if cur.fetchone()["c"] == 0:
                insert_notification(
                    "system",
                    "Welcome to GAEA",
                    "Explore events near you and never miss out again.",
                )

            con.commit()

        if created:
            _wake_streams([account_id])
        return {"AccountID": account_id, "CreatedCount": created}

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})