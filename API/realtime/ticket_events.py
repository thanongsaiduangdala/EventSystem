"""Pushes ticket check-in changes to the customer app in real time.

How it fits together
--------------------
* The customer app (MyTicketPage) opens a WebSocket and authenticates with
  its JWT (see `ticket_status_socket` in TicketAttendence_controllers.py).
  The socket is registered here under the customer's account id.
* When staff check a ticket in / cancel it / revoke it, the controller calls
  `publish_check_in_change(...)`. That looks up which account owns the ticket
  (ticketattendence -> ordersinfo.AccountID) and sends the message to every
  socket that account has open.

NOTE: connections live in this process's memory. That is correct for a single
uvicorn process. If you run several workers / servers, each one only knows its
own sockets, so swap `TicketEventHub` for a Redis pub/sub version.
"""
import asyncio
import logging
from collections import defaultdict
from typing import Any, Dict, List, Optional, Set

logger = logging.getLogger(__name__)

SEND_TIMEOUT_SECONDS = 5


def _iso(value: Any) -> Optional[str]:
    if value is None:
        return None
    return value.isoformat() if hasattr(value, "isoformat") else str(value)


class TicketEventHub:
    """Tracks open customer sockets per account and fans messages out to them."""

    def __init__(self) -> None:
        self._sockets: Dict[int, Set[Any]] = defaultdict(set)

    def register(self, account_id: int, websocket: Any) -> None:
        self._sockets[account_id].add(websocket)

    def unregister(self, account_id: int, websocket: Any) -> None:
        sockets = self._sockets.get(account_id)
        if not sockets:
            return
        sockets.discard(websocket)
        if not sockets:
            self._sockets.pop(account_id, None)

    def connection_count(self, account_id: int) -> int:
        return len(self._sockets.get(account_id, ()))

    async def notify_account(self, account_id: int, message: dict) -> None:
        sockets = list(self._sockets.get(account_id, ()))
        if not sockets:
            return

        async def _send(ws: Any) -> bool:
            try:
                await asyncio.wait_for(ws.send_json(message), SEND_TIMEOUT_SECONDS)
                return True
            except Exception:
                return False

        results = await asyncio.gather(*(_send(ws) for ws in sockets))
        for ws, ok in zip(sockets, results):
            if not ok:  # dead or stuck connection; drop it
                self.unregister(account_id, ws)


hub = TicketEventHub()


def get_attendee_owner(con, attendee_id: int) -> Optional[int]:
    """AccountID of the customer who bought this attendee's ticket."""
    with con.cursor() as cur:
        cur.execute(
            """
            SELECT o.AccountID
            FROM ticketattendence ta
            JOIN ordersinfo o ON o.OrderID = ta.OrderID
            WHERE ta.attendeeID = %s
            """,
            (attendee_id,),
        )
        row = cur.fetchone()
    return row["AccountID"] if row else None


def get_ticket_snapshot(con, account_id: int, event_id: int) -> List[dict]:
    """Current check-in state of every ticket this account owns for an event."""
    with con.cursor() as cur:
        cur.execute(
            """
            SELECT ta.attendeeID, ta.IsValid, tc.CheckedInAtYMDT
            FROM ticketattendence ta
            JOIN ordersinfo o ON o.OrderID = ta.OrderID
            JOIN tickettype tt ON tt.TicketTypeID = ta.TicketTypeID
            LEFT JOIN ticketcheckin tc
                ON tc.attendeeID = ta.attendeeID AND tc.EventID = tt.EventID
            WHERE o.AccountID = %s AND tt.EventID = %s
            """,
            (account_id, event_id),
        )
        rows = cur.fetchall()
    return [
        {
            "attendeeID": r["attendeeID"],
            "isValid": bool(r["IsValid"]),
            "checkedInAt": _iso(r["CheckedInAtYMDT"]),
        }
        for r in rows
    ]


async def publish_check_in_change(
    con, *, attendee_id: int, event_id: int, checked_in_at: Any = None
) -> None:
    """Tell the ticket owner their ticket was checked in (checked_in_at set)
    or that the check-in was undone (checked_in_at None).

    Never raises: the staff member's check-in has already been committed, and
    a failed push must not turn that into an error response.
    """
    try:
        account_id = get_attendee_owner(con, attendee_id)
        if account_id is None:
            return
        if checked_in_at is None:
            message = {
                "type": "check_in_cancelled",
                "attendeeID": attendee_id,
                "eventID": event_id,
            }
        else:
            message = {
                "type": "checked_in",
                "attendeeID": attendee_id,
                "eventID": event_id,
                "checkedInAt": _iso(checked_in_at),
            }
        await hub.notify_account(account_id, message)
    except Exception:
        logger.exception("Failed to publish ticket check-in change")
