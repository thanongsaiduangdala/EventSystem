import asyncio
import logging

import pymysql
from fastapi import HTTPException, status, Depends, WebSocket, WebSocketDisconnect
from DB.DBConnect import getConnect
from models.schema import (
    AddTicketAttendenceRequest,
    UpdateTicketAttendenceRequest,
    CheckInAttendeeRequest,
    RevokeTicketRequest,
)
from auth.dependencies import get_current_account
from auth.jwt_handler import decode_access_token
from auth.team_access import (
    ensure_team_access,
    ensure_scan_access,
    ensure_attendee_list_access,
    ensure_staff_or_manager,
    ensure_member_row,
    event_org_id,
)
from controllers.Event_Controllers.EventQuestion_Controllers import _deserialize_row
from realtime.ticket_events import hub, publish_check_in_change, get_ticket_snapshot

logger = logging.getLogger(__name__)

def _national_id_uniqueness_error(event_id: int, national_id: str):
    return HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail=f"A ticket for this National ID is already registered for event {event_id}",
    )


async def _national_id_in_use(cur, event_id: int, national_id: str, exclude_attendee_id=None):
    if national_id is None:
        return False

    sql = """
        SELECT COUNT(*) AS cnt
        FROM ticketattendence ta
        JOIN tickettype tt ON ta.TicketTypeID = tt.TicketTypeID
        JOIN eventinfo ev ON tt.EventID = ev.EventID
        WHERE ev.EventID = %s
          AND ev.OnePerPerson = 1
          AND UPPER(REPLACE(TRIM(ta.NationalID), ' ', '')) = UPPER(REPLACE(TRIM(%s), ' ', ''))
    """
    params = [event_id, national_id]
    if exclude_attendee_id is not None:
        sql += " AND ta.attendeeID <> %s"
        params.append(exclude_attendee_id)

    cur.execute(sql, params)
    row = cur.fetchone()
    return (row or {}).get("cnt", 0) > 0


async def create_ticketattendee(req_data: AddTicketAttendenceRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("SELECT EventID FROM tickettype WHERE TicketTypeID = %s", (req_data.TicketTypeID,))
            ticket_row = cur.fetchone()
            event_id = (ticket_row or {}).get("EventID")

            if req_data.NationalID and event_id and \
               await _national_id_in_use(cur, event_id, req_data.NationalID):
                raise _national_id_uniqueness_error(event_id, req_data.NationalID)

            sql = """
                INSERT INTO ticketattendence
                (TicketTypeID, OrderID, FirstName, LastName, PhoneNum, Email, NationalID)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
            """
            cur.execute(sql, (
                req_data.TicketTypeID,
                req_data.OrderID,
                req_data.FirstName,
                req_data.LastName,
                req_data.PhoneNum,
                req_data.Email,
                req_data.NationalID,
            ))
            con.commit()
            Attendee_ID = cur.lastrowid

        return {"msg": "Ticket attendee created successfully", "attendeeID": Attendee_ID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_all_TicketAttendees():
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM ticketattendence"
            cur.execute(sql)
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_ticketattendee_by_id(attendee_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM ticketattendence WHERE attendeeID = %s"
            cur.execute(sql, (attendee_id,))
            row = cur.fetchone()

        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ticket attendee not found")

        return row

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_ticketattendees_by_order_id(order_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM ticketattendence WHERE OrderID = %s"
            cur.execute(sql, (order_id,))
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def update_ticketattendee(req_data: UpdateTicketAttendenceRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("SELECT EventID FROM tickettype WHERE TicketTypeID = %s", (req_data.TicketTypeID,))
            ticket_row = cur.fetchone()
            event_id = (ticket_row or {}).get("EventID")

            if req_data.NationalID and event_id and \
               await _national_id_in_use(cur, event_id, req_data.NationalID, exclude_attendee_id=req_data.attendeeID):
                raise _national_id_uniqueness_error(event_id, req_data.NationalID)

            sql = """
                UPDATE ticketattendence
                SET TicketTypeID = %s,
                    OrderID = %s,
                    FirstName = %s,
                    LastName = %s,
                    PhoneNum = %s,
                    Email = %s,
                    NationalID = %s
                WHERE attendeeID = %s
            """
            cur.execute(sql, (
                req_data.TicketTypeID,
                req_data.OrderID,
                req_data.FirstName,
                req_data.LastName,
                req_data.PhoneNum,
                req_data.Email,
                req_data.NationalID,
                req_data.attendeeID,
            ))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ticket attendee not found")

            con.commit()

        return {"msg": "Ticket attendee updated successfully", "attendeeID": req_data.attendeeID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def delete_ticketattendee(attendee_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "DELETE FROM ticketattendence WHERE attendeeID = %s"
            cur.execute(sql, (attendee_id,))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ticket attendee not found")

            con.commit()

        return {"msg": "Ticket attendee deleted successfully", "attendeeID": attendee_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_event_attendees(event_id: int, current=Depends(get_current_account)):
    try:
        con = getConnect()
        await ensure_attendee_list_access(con, current, event_id)

        with con.cursor() as cur:
            cur.execute(
                """
                SELECT ta.attendeeID, ta.TicketTypeID, ta.OrderID,
                       ta.FirstName, ta.LastName, ta.PhoneNum, ta.Email,
                       ta.NationalID, ta.IsValid,
                       tt.TypeName AS TicketTypeName,
                       tt.PriceInKIP AS TicketPrice, tt.EventID,
                       o.PaymentDateYMDT,
                       tc.CheckInID, tc.CheckedInByMemberID, tc.CheckedInAtYMDT,
                       CONCAT(acc.FirstName, ' ', acc.LastName) AS CheckedInByName
                FROM ticketattendence ta
                JOIN tickettype tt ON ta.TicketTypeID = tt.TicketTypeID
                LEFT JOIN ordersinfo o ON o.OrderID = ta.OrderID
                LEFT JOIN ticketcheckin tc
                    ON tc.attendeeID = ta.attendeeID AND tc.EventID = %s
                LEFT JOIN organizermember om ON om.MemberID = tc.CheckedInByMemberID
                LEFT JOIN accountinfo acc ON acc.AccountID = om.AccountID
                WHERE tt.EventID = %s
                ORDER BY ta.attendeeID DESC
                """,
                (event_id, event_id),
            )
            rows = cur.fetchall()

        return rows

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def resolve_attendee_for_checkin(event_id: int, attendee_id: int, current=Depends(get_current_account)):
    try:
        con = getConnect()
        await ensure_scan_access(con, current, event_id)

        with con.cursor() as cur:
            cur.execute(
                """
                SELECT ta.attendeeID, ta.FirstName, ta.LastName, ta.IsValid,
                       tt.TypeName AS TicketTypeName, tt.EventID,
                       tc.CheckInID, tc.CheckedInAtYMDT
                FROM ticketattendence ta
                JOIN tickettype tt ON ta.TicketTypeID = tt.TicketTypeID
                LEFT JOIN ticketcheckin tc
                    ON tc.attendeeID = ta.attendeeID AND tc.EventID = %s
                WHERE ta.attendeeID = %s AND tt.EventID = %s
                """,
                (event_id, attendee_id, event_id),
            )
            row = cur.fetchone()

        if row is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Attendee not found for this event",
            )
        return row

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def check_in_attendee(req_data: CheckInAttendeeRequest, current=Depends(get_current_account)):
    try:
        con = getConnect()
        member = await ensure_scan_access(con, current, req_data.EventID)

        org_id = event_org_id(con, req_data.EventID)
        member_id = None
        if member is not None and member.get("MemberID"):
            member_id = member["MemberID"]
        else:
            member_id = ensure_member_row(con, current["account_id"], org_id)

        with con.cursor() as cur:
            cur.execute(
                """
                SELECT ta.attendeeID, ta.IsValid
                FROM ticketattendence ta
                JOIN tickettype tt ON ta.TicketTypeID = tt.TicketTypeID
                WHERE ta.attendeeID = %s AND tt.EventID = %s
                """,
                (req_data.AttendeeID, req_data.EventID),
            )
            attendee = cur.fetchone()
            if not attendee:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Attendee not found for this event")

            if not attendee["IsValid"]:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="This ticket has been revoked and cannot be checked in",
                )

            cur.execute(
                "SELECT CheckInID FROM ticketcheckin WHERE attendeeID = %s AND EventID = %s",
                (req_data.AttendeeID, req_data.EventID),
            )
            if cur.fetchone() is not None:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="This attendee has already been checked in",
                )

            cur.execute(
                "INSERT INTO ticketcheckin (attendeeID, EventID, CheckedInByMemberID) VALUES (%s, %s, %s)",
                (req_data.AttendeeID, req_data.EventID, member_id),
            )
            con.commit()
            check_in_id = cur.lastrowid

            cur.execute(
                "SELECT CheckedInAtYMDT FROM ticketcheckin WHERE CheckInID = %s",
                (check_in_id,),
            )
            checked_in_at = (cur.fetchone() or {}).get("CheckedInAtYMDT")

        # Let the ticket owner's app know, in real time.
        await publish_check_in_change(
            con,
            attendee_id=req_data.AttendeeID,
            event_id=req_data.EventID,
            checked_in_at=checked_in_at,
        )

        return {"msg": "Attendee checked in", "CheckInID": check_in_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        if err.args and err.args[0] == 1062:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="This attendee has already been checked in")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def cancel_check_in_attendee(req_data: CheckInAttendeeRequest, current=Depends(get_current_account)):
    try:
        con = getConnect()
        await ensure_scan_access(con, current, req_data.EventID)

        with con.cursor() as cur:
            cur.execute(
                """
                SELECT ta.attendeeID
                FROM ticketattendence ta
                JOIN tickettype tt ON ta.TicketTypeID = tt.TicketTypeID
                WHERE ta.attendeeID = %s AND tt.EventID = %s
                """,
                (req_data.AttendeeID, req_data.EventID),
            )
            if cur.fetchone() is None:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Attendee not found for this event")

            cur.execute(
                "DELETE FROM ticketcheckin WHERE attendeeID = %s AND EventID = %s",
                (req_data.AttendeeID, req_data.EventID),
            )
            if cur.rowcount == 0:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="This attendee is not checked in",
                )
            con.commit()

        await publish_check_in_change(
            con,
            attendee_id=req_data.AttendeeID,
            event_id=req_data.EventID,
            checked_in_at=None,
        )

        return {"msg": "Check-in cancelled", "attendeeID": req_data.AttendeeID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def revoke_ticket(req_data: RevokeTicketRequest, current=Depends(get_current_account)):
    try:
        con = getConnect()
        await ensure_staff_or_manager(con, current, req_data.EventID)

        with con.cursor() as cur:
            cur.execute(
                """
                SELECT ta.attendeeID
                FROM ticketattendence ta
                JOIN tickettype tt ON ta.TicketTypeID = tt.TicketTypeID
                WHERE ta.attendeeID = %s AND tt.EventID = %s
                """,
                (req_data.AttendeeID, req_data.EventID),
            )
            if cur.fetchone() is None:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Attendee not found for this event")

            cur.execute(
                "UPDATE ticketattendence SET IsValid = %s WHERE attendeeID = %s",
                (1 if req_data.IsValid else 0, req_data.AttendeeID),
            )
            removed_check_in = False
            if not req_data.IsValid:
                cur.execute(
                    "DELETE FROM ticketcheckin WHERE attendeeID = %s AND EventID = %s",
                    (req_data.AttendeeID, req_data.EventID),
                )
                removed_check_in = cur.rowcount > 0
            con.commit()

        if removed_check_in:
            await publish_check_in_change(
                con,
                attendee_id=req_data.AttendeeID,
                event_id=req_data.EventID,
                checked_in_at=None,
            )

        action = "revoked" if not req_data.IsValid else "re-validated"
        return {"msg": f"Ticket {action}", "attendeeID": req_data.AttendeeID, "IsValid": req_data.IsValid}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_event_analytics(event_id: int, current=Depends(get_current_account)):
    try:
        con = getConnect()
        await ensure_attendee_list_access(con, current, event_id)

        with con.cursor() as cur:
            cur.execute(
                """
                SELECT ta.attendeeID, ta.TicketTypeID, ta.OrderID,
                       ta.FirstName, ta.LastName, ta.PhoneNum, ta.Email,
                       ta.NationalID, ta.IsValid,
                       tt.TypeName AS TicketTypeName,
                       tt.PriceInKIP AS TicketPrice, tt.EventID,
                       o.PaymentDateYMDT,
                       tc.CheckInID, tc.CheckedInByMemberID, tc.CheckedInAtYMDT,
                       CONCAT(acc.FirstName, ' ', acc.LastName) AS CheckedInByName
                FROM ticketattendence ta
                JOIN tickettype tt ON ta.TicketTypeID = tt.TicketTypeID
                LEFT JOIN ordersinfo o ON o.OrderID = ta.OrderID
                LEFT JOIN ticketcheckin tc
                    ON tc.attendeeID = ta.attendeeID AND tc.EventID = %s
                LEFT JOIN organizermember om ON om.MemberID = tc.CheckedInByMemberID
                LEFT JOIN accountinfo acc ON acc.AccountID = om.AccountID
                WHERE tt.EventID = %s
                ORDER BY ta.attendeeID ASC
                """,
                (event_id, event_id),
            )
            attendees = cur.fetchall()

            cur.execute("SELECT * FROM tickettype WHERE EventID = %s", (event_id,))
            tickettypes = cur.fetchall()

            cur.execute(
                """
                SELECT EventQuestionID, EventID, EventQuestion, EventQuestionTypeID,
                       IsRequire, SortOrder, Options
                FROM eventquestioninfo
                WHERE EventID = %s
                ORDER BY SortOrder
                """,
                (event_id,),
            )
            questions = [_deserialize_row(r) for r in cur.fetchall()]

            cur.execute(
                """
                SELECT r.ResponseID, r.EventQuestionID, r.attendeeID, r.attendeeAnswer
                FROM attendeeresponse r
                JOIN ticketattendence ta ON ta.attendeeID = r.attendeeID
                JOIN tickettype tt ON tt.TicketTypeID = ta.TicketTypeID
                WHERE tt.EventID = %s
                """,
                (event_id,),
            )
            responses = cur.fetchall()

        return {
            "attendees": attendees,
            "tickettypes": tickettypes,
            "questions": questions,
            "responses": responses,
        }

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


AUTH_TIMEOUT_SECONDS = 10
WS_CLOSE_UNAUTHORIZED = 4401


async def ticket_status_socket(websocket: WebSocket):
    """Live check-in status for the signed-in customer's tickets.

    Protocol (JSON text frames):
      client -> {"type": "auth", "token": "<JWT>", "eventID": 12}   (first frame)
      server -> {"type": "snapshot", "tickets": [{attendeeID, isValid, checkedInAt}]}
      server -> {"type": "checked_in", attendeeID, eventID, checkedInAt}
      server -> {"type": "check_in_cancelled", attendeeID, eventID}
      client -> "ping"   server -> "pong"                     (keep-alive)

    The token is sent as the first frame instead of in the URL so it never
    ends up in access logs. Closes with 4401 when auth fails, which tells the
    app not to keep retrying.
    """
    await websocket.accept()

    try:
        first = await asyncio.wait_for(websocket.receive_json(), AUTH_TIMEOUT_SECONDS)
        if first.get("type") != "auth":
            raise ValueError("first frame must be auth")
        payload = decode_access_token(first["token"])
        account_id = int(payload["sub"])
        event_id = int(first["eventID"])
    except WebSocketDisconnect:
        return
    except Exception:
        await websocket.close(code=WS_CLOSE_UNAUTHORIZED)
        return

    # Register before reading the snapshot so a check-in that lands in between
    # is not missed.
    hub.register(account_id, websocket)
    try:
        con = getConnect()
        if con is None:
            await websocket.close(code=1011)
            return
        try:
            tickets = get_ticket_snapshot(con, account_id, event_id)
        finally:
            con.close()
        await websocket.send_json({"type": "snapshot", "tickets": tickets})

        while True:
            text = await websocket.receive_text()
            if text == "ping":
                await websocket.send_text("pong")
    except WebSocketDisconnect:
        pass
    except Exception:
        logger.exception("ticket_status_socket failed")
    finally:
        hub.unregister(account_id, websocket)
