import asyncio
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


def notify_accounts(recipient_ids, notification_type: str, title: str, body: str) -> None:
    """
    Inserts one notification row per recipient. Best-effort: failures are
    swallowed so a notification problem never breaks the caller's flow.
    """
    if not recipient_ids:
        return
    con = getConnect()
    try:
        with con.cursor() as cur:
            for account_id in set(recipient_ids):
                cur.execute(
                    """
                    INSERT INTO notificationinfo (AccountID, NotificationType, Title, Body)
                    VALUES (%s, %s, %s, %s)
                    """,
                    (account_id, notification_type, title, body),
                )
        con.commit()
    except pymysql.MySQLError:
        pass
    finally:
        con.close()


async def stream_notifications(current=Depends(get_current_account)):
    """
    Server-Sent Events endpoint. Pushes a `data: {"UnreadCount": N}` event
    every time the account's unread notification count changes, so the Flutter
    app can refresh instantly instead of reloading or waiting for a poll.
    Sends a keep-alive comment so the connection stays open on idle proxies.
    """
    async def event_stream():
        con = None
        last_count = -1
        try:
            while True:
                try:
                    if con is None:
                        con = getConnect()
                    with con.cursor() as cur:
                        cur.execute(
                            "SELECT COUNT(*) AS c FROM notificationinfo "
                            "WHERE AccountID = %s AND IsRead = 0",
                            (current["account_id"],),
                        )
                        row = cur.fetchone()
                        count = row["c"] if row else 0
                except pymysql.MySQLError:
                    break

                if count != last_count:
                    last_count = count
                    yield f"data: {{\"UnreadCount\": {count}}}\n\n"
                else:
                    yield ": keep-alive\n\n"

                await asyncio.sleep(2)
        except asyncio.CancelledError:
            pass
        finally:
            if con is not None:
                con.close()

    return StreamingResponse(event_stream(), media_type="text/event-stream")


async def create_notification(req_data: AddNotificationRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                INSERT INTO notificationinfo
                (AccountID, NotificationType, Title, Body)
                VALUES (%s, %s, %s, %s)
            """
            cur.execute(sql, (
                req_data.AccountID,
                req_data.NotificationType,
                req_data.Title,
                req_data.Body,
            ))
            con.commit()
            notification_id = cur.lastrowid

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
            def insert_notification(ntype, title, body):
                nonlocal created
                cur.execute(
                    "SELECT COUNT(*) AS c FROM notificationinfo WHERE AccountID = %s AND Title = %s",
                    (account_id, title),
                )
                if cur.fetchone()["c"] > 0:
                    return
                cur.execute(
                    "INSERT INTO notificationinfo (AccountID, NotificationType, Title, Body) VALUES (%s, %s, %s, %s)",
                    (account_id, ntype, title, body),
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

        return {"AccountID": account_id, "CreatedCount": created}

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})