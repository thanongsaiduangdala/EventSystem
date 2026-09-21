import pymysql
from fastapi import HTTPException, status
from DB.DBConnect import getConnect
from models.schema import AddTicketAttendenceRequest, UpdateTicketAttendenceRequest

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
