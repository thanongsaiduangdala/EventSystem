import pymysql
from fastapi import HTTPException, status
from DB.DBConnect import getConnect
from models.schema import AddOrganizerMemberRequest, UpdateOrganizerMemberRequest


async def create_organizermember(req_data: AddOrganizerMemberRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            # An account may only belong to one organization at a time.
            cur.execute(
                "SELECT MemberID FROM organizermember WHERE AccountID = %s",
                (req_data.AccountID,),
            )
            if cur.fetchone() is not None:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="This account already belongs to an organization",
                )

            sql = """
                INSERT INTO organizermember
                (AccountID, EventOrganizerID, TeamRoleID)
                VALUES (%s, %s, %s)
            """
            cur.execute(sql, (
                req_data.AccountID,
                req_data.EventOrganizerID,
                req_data.TeamRoleID,
            ))
            con.commit()
            Member_ID = cur.lastrowid

        return {"msg": "Organizer member created successfully", "MemberID": Member_ID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_all_OrganizerMembers():
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM organizermember"
            cur.execute(sql)
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_organizermember_by_id(member_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM organizermember WHERE MemberID = %s"
            cur.execute(sql, (member_id,))
            row = cur.fetchone()

        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organizer member not found")

        return row

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def update_organizermember(req_data: UpdateOrganizerMemberRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            # Confirm the row exists via SELECT rather than relying on
            # UPDATE rowcount, which is 0 for "matched but unchanged" rows
            # too and would otherwise falsely report "not found".
            cur.execute(
                "SELECT MemberID FROM organizermember WHERE MemberID = %s",
                (req_data.MemberID,),
            )
            if cur.fetchone() is None:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organizer member not found")

            # One organization per account, excluding this record itself.
            cur.execute(
                "SELECT MemberID FROM organizermember WHERE AccountID = %s AND MemberID != %s",
                (req_data.AccountID, req_data.MemberID),
            )
            if cur.fetchone() is not None:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="This account already belongs to an organization",
                )

            sql = """
                UPDATE organizermember
                SET AccountID = %s,
                    EventOrganizerID = %s,
                    TeamRoleID = %s
                WHERE MemberID = %s
            """
            cur.execute(sql, (
                req_data.AccountID,
                req_data.EventOrganizerID,
                req_data.TeamRoleID,
                req_data.MemberID,
            ))
            con.commit()

        return {"msg": "Organizer member updated successfully", "MemberID": req_data.MemberID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def delete_organizermember(member_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "DELETE FROM organizermember WHERE MemberID = %s"
            cur.execute(sql, (member_id,))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organizer member not found")

            con.commit()

        return {"msg": "Organizer member deleted successfully", "MemberID": member_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})
