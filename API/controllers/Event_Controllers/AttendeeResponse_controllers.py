"""
Attendee registration answers are private: everyone may create one for
themselves, and only the ticket buyer (or a SUPERADMIN) may modify one.

Reading:
  - /response/all is a SUPERADMIN-only dump (developer tool).
  - a single attendee's answers may be read by the buyer/owner, a SUPERADMIN,
    or a team member (Volunteer / Staff / manager) assigned to that attendee's
    event. A Page Designer edits content and has no attendee access.
  - the /response/event/{event_id}/attendee/{attendee_id} endpoint backs the
    door check-in flow and requires team access to the event.
"""
import json

import pymysql
from fastapi import Depends, HTTPException, status
from DB.DBConnect import getConnect
from models.schema import AddAttendeeResponseRequest, UpdateAttendeeResponseRequest
from auth.dependencies import ROLE_SUPERADMIN, get_current_account, require_superadmin
from auth.team_access import ensure_team_access


def _attendee_event_and_owner(con, attendee_id: int):
    """Map an attendee to their event + the account that owns their order."""
    with con.cursor() as cur:
        cur.execute(
            """
            SELECT tt.EventID AS event_id, o.AccountID AS account_id
            FROM ticketattendence ta
            JOIN tickettype tt ON tt.TicketTypeID = ta.TicketTypeID
            JOIN ordersinfo o ON o.OrderID = ta.OrderID
            WHERE ta.attendeeID = %s
            """,
            (attendee_id,),
        )
        row = cur.fetchone()
    return row


def _response_attendee_id(con, response_id: int):
    with con.cursor() as cur:
        cur.execute(
            "SELECT attendeeID FROM attendeeresponse WHERE ResponseID = %s",
            (response_id,),
        )
        row = cur.fetchone()
    return row["attendeeID"] if row else None


def _is_superadmin(con, account_id: int) -> bool:
    with con.cursor() as cur:
        cur.execute(
            "SELECT StatusID FROM accountinfo WHERE AccountID = %s",
            (account_id,),
        )
        row = cur.fetchone()
    return bool(row and row["StatusID"] == ROLE_SUPERADMIN)


async def _ensure_owner(con, current: dict, attendee_id: int) -> None:
    """Writing an attendee's answers is limited to their ticket buyer."""
    if _is_superadmin(con, current["account_id"]):
        return
    attendance = _attendee_event_and_owner(con, attendee_id)
    if attendance is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Attendee not found")
    if current["account_id"] == attendance["account_id"]:
        return
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Only the ticket buyer may manage this attendee's answers",
    )


async def _ensure_owner_or_team(con, current: dict, attendee_id: int) -> dict:
    """Reading an attendee's answers requires owning their order, SUPERADMIN,
    or team access (Volunteer / Staff / manager) to their event."""
    if _is_superadmin(con, current["account_id"]):
        return {}
    attendance = _attendee_event_and_owner(con, attendee_id)
    if attendance is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Attendee not found")
    if current["account_id"] == attendance["account_id"]:
        return attendance
    await ensure_team_access(con, current, attendance["event_id"])
    return attendance


async def create_attendeeresponse(req_data: AddAttendeeResponseRequest, current=Depends(get_current_account)):
    try:
        con = getConnect()
        await _ensure_owner(con, current, req_data.attendeeID)
        with con.cursor() as cur:
            sql = """
                INSERT INTO attendeeresponse
                (EventQuestionID, attendeeID, attendeeAnswer)
                VALUES (%s, %s, %s)
            """
            cur.execute(sql, (
                req_data.EventQuestionID,
                req_data.attendeeID,
                req_data.attendeeAnswer,
            ))
            Response_ID = cur.lastrowid
            con.commit()

        return {"msg": "Attendee response created successfully", "ResponseID": Response_ID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_all_AttendeeResponses(current=Depends(require_superadmin)):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM attendeeresponse"
            cur.execute(sql)
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_attendeeresponse_by_id(response_id: int, current=Depends(get_current_account)):
    try:
        con = getConnect()
        attendee_id = _response_attendee_id(con, response_id)
        if attendee_id is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Attendee response not found")
        await _ensure_owner_or_team(con, current, attendee_id)

        with con.cursor() as cur:
            sql = "SELECT * FROM attendeeresponse WHERE ResponseID = %s"
            cur.execute(sql, (response_id,))
            row = cur.fetchone()

        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Attendee response not found")

        return row

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_attendeeresponses_by_attendee_id(attendee_id: int, current=Depends(get_current_account)):
    """Convenience lookup: all question responses for a given attendeeID."""
    try:
        con = getConnect()
        await _ensure_owner_or_team(con, current, attendee_id)
        with con.cursor() as cur:
            sql = "SELECT * FROM attendeeresponse WHERE attendeeID = %s"
            cur.execute(sql, (attendee_id,))
            rows = cur.fetchall()

        return rows

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def update_attendeeresponse(req_data: UpdateAttendeeResponseRequest, current=Depends(get_current_account)):
    try:
        con = getConnect()
        existing_attendee_id = _response_attendee_id(con, req_data.ResponseID)
        if existing_attendee_id is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Attendee response not found")
        await _ensure_owner(con, current, existing_attendee_id)
        if req_data.attendeeID != existing_attendee_id:
            await _ensure_owner(con, current, req_data.attendeeID)

        with con.cursor() as cur:
            sql = """
                UPDATE attendeeresponse
                SET EventQuestionID = %s,
                    attendeeID = %s,
                    attendeeAnswer = %s
                WHERE ResponseID = %s
            """
            cur.execute(sql, (
                req_data.EventQuestionID,
                req_data.attendeeID,
                req_data.attendeeAnswer,
                req_data.ResponseID,
            ))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Attendee response not found")

            con.commit()

        return {"msg": "Attendee response updated successfully", "ResponseID": req_data.ResponseID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def delete_attendeeresponse(response_id: int, current=Depends(get_current_account)):
    try:
        con = getConnect()
        attendee_id = _response_attendee_id(con, response_id)
        if attendee_id is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Attendee response not found")
        await _ensure_owner(con, current, attendee_id)

        with con.cursor() as cur:
            sql = "DELETE FROM attendeeresponse WHERE ResponseID = %s"
            cur.execute(sql, (response_id,))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Attendee response not found")

            con.commit()

        return {"msg": "Attendee response deleted successfully", "ResponseID": response_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_question_responses_for_checkin(event_id: int, attendee_id: int, current=Depends(get_current_account)):
    """Questions + a scanned attendee's answers, for door verification.

    Requires team access to the event (Volunteer / Staff / manager). A Page
    Designer may not read attendee answers. See auth.team_access.
    """
    try:
        con = getConnect()
        if not _is_superadmin(con, current["account_id"]):
            await ensure_team_access(con, current, event_id)

        with con.cursor() as cur:
            cur.execute(
                """
                SELECT 1 FROM ticketattendence ta
                JOIN tickettype tt ON tt.TicketTypeID = ta.TicketTypeID
                WHERE ta.attendeeID = %s AND tt.EventID = %s
                """,
                (attendee_id, event_id),
            )
            if cur.fetchone() is None:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Attendee not found for this event",
                )

        with con.cursor() as cur:
            cur.execute(
                """
                SELECT q.EventQuestionID, q.EventQuestion, q.EventQuestionTypeID,
                       q.IsRequire, q.SortOrder, q.Options,
                       r.attendeeAnswer
                FROM eventquestioninfo q
                LEFT JOIN attendeeresponse r
                  ON r.EventQuestionID = q.EventQuestionID AND r.attendeeID = %s
                WHERE q.EventID = %s
                ORDER BY q.SortOrder, q.EventQuestionID
                """,
                (attendee_id, event_id),
            )
            rows = cur.fetchall()

        questions = []
        for row in rows:
            options = row["Options"]
            if options:
                try:
                    options = json.loads(options)
                except (TypeError, ValueError):
                    options = None
            questions.append({
                "EventQuestionID": row["EventQuestionID"],
                "EventQuestion": row["EventQuestion"],
                "EventQuestionTypeID": row["EventQuestionTypeID"],
                "IsRequire": row["IsRequire"],
                "SortOrder": row["SortOrder"],
                "Options": options,
                "attendeeAnswer": row["attendeeAnswer"],
            })

        return {"event_id": event_id, "attendee_id": attendee_id, "questions": questions}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})