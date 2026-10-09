import asyncio
import logging

from fastapi import WebSocket, WebSocketDisconnect
from DB.DBConnect import getConnect
from auth.jwt_handler import decode_access_token
from realtime.review_events import hub

logger = logging.getLogger(__name__)

AUTH_TIMEOUT_SECONDS = 10
WS_CLOSE_UNAUTHORIZED = 4401
STAFF_STATUS_IDS = (3, 4)  # SUPERADMIN, EMPLOYEE


def _is_staff(account_id: int) -> bool:
    """Looks the role up in the DB (not the token) so a role change applies
    on the next connect."""
    con = getConnect()
    if con is None:
        return False
    try:
        with con.cursor() as cur:
            cur.execute("SELECT StatusID FROM accountinfo WHERE AccountID = %s", (account_id,))
            row = cur.fetchone()
        return row is not None and row["StatusID"] in STAFF_STATUS_IDS
    finally:
        con.close()


async def review_socket(websocket: WebSocket):
    """Live approval changes for the Employee dashboard and the organizer
    dashboard.

    Protocol (JSON text frames):
      client -> {"type": "auth", "token": "<JWT>"}                  (first frame)
      server -> {"type": "ready", "staff": true|false}
      server -> {"type": "review_changed", "kind": "event"|"organization",
                 "id": 12, "statusID": 2, "denyReason": null}
      client -> "ping"   server -> "pong"                           (keep-alive)

    Staff receive every change; anyone else only receives changes to their
    own organization / events. Closes with 4401 when auth fails so the app
    does not keep retrying.
    """
    await websocket.accept()

    try:
        first = await asyncio.wait_for(websocket.receive_json(), AUTH_TIMEOUT_SECONDS)
        if first.get("type") != "auth":
            raise ValueError("first frame must be auth")
        payload = decode_access_token(first["token"])
        account_id = int(payload["sub"])
    except WebSocketDisconnect:
        return
    except Exception:
        await websocket.close(code=WS_CLOSE_UNAUTHORIZED)
        return

    is_staff = await asyncio.to_thread(_is_staff, account_id)
    hub.register(account_id, websocket, is_staff)
    try:
        await websocket.send_json({"type": "ready", "staff": is_staff})
        while True:
            text = await websocket.receive_text()
            if text == "ping":
                await websocket.send_text("pong")
    except WebSocketDisconnect:
        pass
    except Exception:
        logger.exception("review_socket failed")
    finally:
        hub.unregister(account_id, websocket)
