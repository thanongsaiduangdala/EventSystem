import pymysql
from fastapi import HTTPException, status, Depends
from DB.DBConnect import getConnect
from models.schema import (
    AddTicketAttendenceRequest,
    UpdateTicketAttendenceRequest,
    CheckInAttendeeRequest,
    RevokeTicketRequest,
)
from auth.dependencies import get_current_account
from auth.team_access import (
    ensure_team_access,
    ensure_staff_or_manager,
    ensure_member_row,
    event_org_id,
)

# An ID we can successfully match against at the door: Gov ID / National ID /
# Passport. When the event enforces OnePerPerson this value must be unique for
# the event so the same person can't buy a second ticket and resell it.
def _national_id_uniqueness_error(event_id: int, national_id: str):
    return HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail=f"A ticket for this National ID is already registered for event {event_id}",
    )


async def _national_id_in_use(cur, event_id: int, national_id: str, exclude_attendee_id=None):
    """True when another attendee on the given event already uses this ID.

    Only enforced for events with OnePerPerson = 1. Case- and space-insensitive
    so small formatting differences (e.g. '123-456' vs '123456') don't bypass
    the rule -- the exact match strategy is on the normalized value.
    """
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
            # Resolve the event this attendee belongs to (via their ticket type).
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
    """Convenience lookup: all attendees tied to a given OrderID."""
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
            # Resolve the event this attendee belongs to (via their ticket type).
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


# ---------------------------------------------------------------------------
# Team check-in endpoints.
#
# Attendee data and check-in are guarded by the caller's *team* role (see
# auth.team_access): a manager of the event's organization always qualifies,
# while volunteers/staff must be assigned to that specific event.
# ---------------------------------------------------------------------------

async def get_event_attendees(event_id: int, current=Depends(get_current_account)):
    """
    Every attendee of an event with ticket, order, ticket-validity and
    check-in state, so the check-in screen can render one list for both
    volunteers (scan/verify) and staff (manage/revoke).
    """
    try:
        con = getConnect()
        await ensure_team_access(con, current, event_id)

        with con.cursor() as cur:
            cur.execute(
                """
                SELECT ta.attendeeID, ta.TicketTypeID, ta.OrderID,
                       ta.FirstName, ta.LastName, ta.PhoneNum, ta.Email,
                       ta.NationalID, ta.IsValid,
                       tt.TicketTypeName, tt.TicketPrice, tt.EventID,
                       o.PaymentDateYMDT,
                       tc.CheckInID, tc.CheckedInByMemberID, tc.CheckedInAtYMDT
                FROM ticketattendence ta
                JOIN tickettype tt ON ta.TicketTypeID = tt.TicketTypeID
                LEFT JOIN ordersinfo o ON o.OrderID = ta.OrderID
                LEFT JOIN ticketcheckin tc
                    ON tc.attendeeID = ta.attendeeID AND tc.EventID = %s
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


async def check_in_attendee(req_data: CheckInAttendeeRequest, current=Depends(get_current_account)):
    """
    Marks an attendee as checked in for an event. Only allowed when the caller
    may work the event (assigned volunteer/staff or a manager), the ticket is
    still marked valid, and the attendee has not already been checked in.
    """
    try:
        con = getConnect()
        member = await ensure_team_access(con, current, req_data.EventID)

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

        return {"msg": "Attendee checked in", "CheckInID": check_in_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        if err.args and err.args[0] == 1062:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="This attendee has already been checked in")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def revoke_ticket(req_data: RevokeTicketRequest, current=Depends(get_current_account)):
    """
    Revokes (or re-validates) an attendee's ticket for an event. Staff+ only;
    volunteers may not revoke. Revoking also clears any prior check-in so the
    attendee cannot sneak in through a stale check-in record.
    """
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
            if not req_data.IsValid:
                cur.execute(
                    "DELETE FROM ticketcheckin WHERE attendeeID = %s AND EventID = %s",
                    (req_data.AttendeeID, req_data.EventID),
                )
            con.commit()

        action = "revoked" if not req_data.IsValid else "re-validated"
        return {"msg": f"Ticket {action}", "attendeeID": req_data.AttendeeID, "IsValid": req_data.IsValid}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})
