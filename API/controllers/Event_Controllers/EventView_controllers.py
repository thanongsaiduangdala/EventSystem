import pymysql
from fastapi import HTTPException, status
from DB.DBConnect import getConnect
from models.schema import AddEventViewRequest


async def create_event_view(req_data: AddEventViewRequest):
    """Record one 'user clicked an event detail' event, used to feed the
    interesting-events recommendation signal."""
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                INSERT INTO eventviewinfo (AccountID, EventID)
                VALUES (%s, %s)
            """
            cur.execute(sql, (req_data.AccountID, req_data.EventID))
            con.commit()
            view_id = cur.lastrowid

        return {"msg": "Event viewed successfully", "ViewID": view_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_all_event_views():
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("SELECT * FROM eventviewinfo")
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_event_views_by_account(account_id: int):
    """Events this account clicked, joined with event details."""
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                SELECT v.ViewID, v.AccountID, v.EventID, v.ViewedAtYMDT,
                       e.EventName, e.EventStartingYMDT, e.EventAddress
                FROM eventviewinfo v
                JOIN eventinfo e ON e.EventID = v.EventID
                WHERE v.AccountID = %s
                ORDER BY v.ViewedAtYMDT DESC
            """
            cur.execute(sql, (account_id,))
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})