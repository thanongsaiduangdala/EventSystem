import pymysql
from fastapi import HTTPException, status
from DB.DBConnect import getConnect
from models.schema import AddFollowRequest


async def create_follow(req_data: AddFollowRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                INSERT INTO followinfo (AccountID, EventOrganizerID)
                VALUES (%s, %s)
            """
            cur.execute(sql, (req_data.AccountID, req_data.EventOrganizerID))
            con.commit()
            follow_id = cur.lastrowid

        return {"msg": "Organizer followed successfully", "FollowID": follow_id}

    except HTTPException:
        raise
    except pymysql.err.IntegrityError:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Organizer already followed by this account")
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_all_follows():
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("SELECT * FROM followinfo")
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_follows_by_account(account_id: int):
    """Organizers followed by one account, joined with organizer info."""
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                SELECT f.FollowID, f.AccountID, f.EventOrganizerID, f.CreatedAtYMDT,
                       o.EventOrganizerName, o.EventOrganizerLogoPath
                FROM followinfo f
                JOIN eventorganizerinfo o ON o.EventOrganizerID = f.EventOrganizerID
                WHERE f.AccountID = %s
                ORDER BY f.CreatedAtYMDT DESC
            """
            cur.execute(sql, (account_id,))
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_followed_events(account_id: int):
    """Events hosted by organizers the account follows -- drives the home page
    "Followed" list."""
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                SELECT e.EventID, e.EventName, e.EventStartingYMDT, e.EventEndingYMDT,
                       e.EventAddress, e.Latitude, e.Longitude, e.EventDescription,
                       e.EventOrganizerID, e.OnePerPerson
                FROM followinfo f
                JOIN eventinfo e ON e.EventOrganizerID = f.EventOrganizerID
                WHERE f.AccountID = %s
                ORDER BY e.EventStartingYMDT ASC
            """
            cur.execute(sql, (account_id,))
            rows = cur.fetchall()

        return {"events": rows}

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def check_follow(account_id: int, organizer_id: int):
    """Whether this account follows this organizer -- drives the follow button state."""
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute(
                "SELECT FollowID FROM followinfo WHERE AccountID = %s AND EventOrganizerID = %s",
                (account_id, organizer_id),
            )
            row = cur.fetchone()

        return {"followed": row is not None}

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def delete_follow(account_id: int, organizer_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute(
                "DELETE FROM followinfo WHERE AccountID = %s AND EventOrganizerID = %s",
                (account_id, organizer_id),
            )
            rows_deleted = cur.rowcount
            con.commit()

        if rows_deleted == 0:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Follow not found")

        return {"msg": "Follow removed successfully", "AccountID": account_id, "EventOrganizerID": organizer_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})