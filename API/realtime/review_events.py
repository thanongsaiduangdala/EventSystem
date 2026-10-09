"""Pushes approval changes (events / organizations) to open apps in real time.

Who gets what
-------------
* Every staff account (EMPLOYEE / SUPERADMIN) with the app open receives every
  change, so a reviewer's Pending / Approved / Denied lists update the moment
  another reviewer decides, or an organizer submits / resubmits something.
* The organization owner receives the changes that concern them, so their
  dashboard flips from "pending" to "approved" / "denied (reason)" without a
  manual refresh.

The message only says "something changed" plus the new status; the app simply
re-fetches the lists. That keeps the server free of any list-rendering logic.

NOTE: like ticket_events.py, connections live in this process's memory. That is
correct for a single uvicorn process; with several workers use Redis pub/sub.
"""
import asyncio
import logging
from collections import defaultdict
from typing import Any, Dict, Optional, Set

logger = logging.getLogger(__name__)

SEND_TIMEOUT_SECONDS = 5


class ReviewEventHub:
    def __init__(self) -> None:
        self._by_account: Dict[int, Set[Any]] = defaultdict(set)
        self._staff: Set[Any] = set()

    def register(self, account_id: int, websocket: Any, is_staff: bool) -> None:
        self._by_account[account_id].add(websocket)
        if is_staff:
            self._staff.add(websocket)

    def unregister(self, account_id: int, websocket: Any) -> None:
        self._staff.discard(websocket)
        sockets = self._by_account.get(account_id)
        if not sockets:
            return
        sockets.discard(websocket)
        if not sockets:
            self._by_account.pop(account_id, None)

    async def broadcast(self, message: dict, owner_account_id: Optional[int] = None) -> None:
        targets: Dict[Any, Optional[int]] = {ws: None for ws in self._staff}
        if owner_account_id is not None:
            for ws in self._by_account.get(owner_account_id, ()):
                targets.setdefault(ws, owner_account_id)
        if not targets:
            return

        async def _send(ws: Any) -> bool:
            try:
                await asyncio.wait_for(ws.send_json(message), SEND_TIMEOUT_SECONDS)
                return True
            except Exception:
                return False

        sockets = list(targets)
        results = await asyncio.gather(*(_send(ws) for ws in sockets))
        for ws, ok in zip(sockets, results):
            if not ok:  # dead or stuck connection; drop it everywhere
                self._staff.discard(ws)
                for account_id, group in list(self._by_account.items()):
                    if ws in group:
                        self.unregister(account_id, ws)


hub = ReviewEventHub()


async def publish_review_change(
    *,
    kind: str,                       # "event" or "organization"
    item_id: int,
    status_id: int,
    owner_account_id: Optional[int] = None,
    deny_reason: Optional[str] = None,
) -> None:
    """Never raises: the change is already committed, and a failed push must
    not turn a successful approve / deny / submit into an error response."""
    try:
        await hub.broadcast(
            {
                "type": "review_changed",
                "kind": kind,
                "id": item_id,
                "statusID": status_id,
                "denyReason": deny_reason,
            },
            owner_account_id=owner_account_id,
        )
    except Exception:
        logger.exception("Failed to publish review change")
