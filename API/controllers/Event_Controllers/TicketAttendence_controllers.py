import pymysql
from fastapi import HTTPException, status
from DB.DBConnect import getConnect
from models.schema import AddTicketAttendenceRequest, UpdateTicketAttendenceRequest


async def create_ticketattendee(req_data: AddTicketAttendenceRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                INSERT INTO ticketattendence
                (TicketTypeID, OrderID, FirstName, LastName, PhoneNum, Email)
                VALUES (%s, %s, %s, %s, %s, %s)
            """
            cur.execute(sql, (
                req_data.TicketTypeID,
                req_data.OrderID,
                req_data.FirstName,
                req_data.LastName,
                req_data.PhoneNum,
                req_data.Email,
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
            sql = """
                UPDATE ticketattendence
                SET TicketTypeID = %s,
                    OrderID = %s,
                    FirstName = %s,
                    LastName = %s,
                    PhoneNum = %s,
                    Email = %s
                WHERE attendeeID = %s
            """
            cur.execute(sql, (
                req_data.TicketTypeID,
                req_data.OrderID,
                req_data.FirstName,
                req_data.LastName,
                req_data.PhoneNum,
                req_data.Email,
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
