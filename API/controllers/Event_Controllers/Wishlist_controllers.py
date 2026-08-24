import pymysql
from fastapi import HTTPException, status
from DB.DBConnect import getConnect
from models.schema import AddWishlistRequest


async def create_wish(req_data: AddWishlistRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                INSERT INTO wishlistinfo (AccountID, EventID)
                VALUES (%s, %s)
            """
            cur.execute(sql, (req_data.AccountID, req_data.EventID))
            con.commit()
            wish_id = cur.lastrowid

        return {"msg": "Event wished successfully", "WishID": wish_id}

    except HTTPException:
        raise
    except pymysql.err.IntegrityError:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Event already wished by this account")
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_all_wishlist():
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("SELECT * FROM wishlistinfo")
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_wishlist_by_account(account_id: int):
    """Wished events for one account, joined with event details for display."""
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                SELECT w.WishID, w.AccountID, w.EventID, w.CreatedAtYMDT,
                       e.EventName, e.EventStartingYMDT, e.EventAddress
                FROM wishlistinfo w
                JOIN eventinfo e ON e.EventID = w.EventID
                WHERE w.AccountID = %s
                ORDER BY w.CreatedAtYMDT DESC
            """
            cur.execute(sql, (account_id,))
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def check_wish(account_id: int, event_id: int):
    """Whether this account has wished this event -- drives the heart icon state."""
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute(
                "SELECT WishID FROM wishlistinfo WHERE AccountID = %s AND EventID = %s",
                (account_id, event_id),
            )
            row = cur.fetchone()

        return {"wished": row is not None}

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def delete_wish(account_id: int, event_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute(
                "DELETE FROM wishlistinfo WHERE AccountID = %s AND EventID = %s",
                (account_id, event_id),
            )
            rows_deleted = cur.rowcount
            con.commit()

        if rows_deleted == 0:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Wish not found")

        return {"msg": "Wish removed successfully", "AccountID": account_id, "EventID": event_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def delete_wish_by_id(wish_id: int):
    """Delete by WishID directly -- used by the admin dashboard table."""
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("DELETE FROM wishlistinfo WHERE WishID = %s", (wish_id,))
            rows_deleted = cur.rowcount
            con.commit()

        if rows_deleted == 0:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Wish not found")

        return {"msg": "Wish removed successfully", "WishID": wish_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})
