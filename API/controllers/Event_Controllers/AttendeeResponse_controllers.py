import pymysql
from fastapi import HTTPException, status
from DB.DBConnect import getConnect
from models.schema import AddAttendeeResponseRequest, UpdateAttendeeResponseRequest


async def create_attendeeresponse(req_data: AddAttendeeResponseRequest):
    try:
        con = getConnect()
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
            con.commit()
            Response_ID = cur.lastrowid

        return {"msg": "Attendee response created successfully", "ResponseID": Response_ID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_all_AttendeeResponses():
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM attendeeresponse"
            cur.execute(sql)
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_attendeeresponse_by_id(response_id: int):
    try:
        con = getConnect()
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


async def get_attendeeresponses_by_attendee_id(attendee_id: int):
    """Convenience lookup: all question responses for a given attendeeID."""
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM attendeeresponse WHERE attendeeID = %s"
            cur.execute(sql, (attendee_id,))
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def update_attendeeresponse(req_data: UpdateAttendeeResponseRequest):
    try:
        con = getConnect()
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


async def delete_attendeeresponse(response_id: int):
    try:
        con = getConnect()
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
