import pymysql
from fastapi import HTTPException, status
from DB.DBConnect import getConnect
from models.schema import AddTeamRoleRequest, UpdateTeamRoleRequest


async def create_teamrole(req_data: AddTeamRoleRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                INSERT INTO teamrole
                (TeamRoleName)
                VALUES (%s)
            """
            cur.execute(sql, (
                req_data.TeamRoleName,
            ))
            con.commit()
            TeamRole_ID = cur.lastrowid

        return {"msg": "Team role created successfully", "TeamRoleID": TeamRole_ID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_all_TeamRoles():
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM teamrole"
            cur.execute(sql)
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_teamrole_by_id(team_role_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM teamrole WHERE TeamRoleID = %s"
            cur.execute(sql, (team_role_id,))
            row = cur.fetchone()

        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Team role not found")

        return row

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def update_teamrole(req_data: UpdateTeamRoleRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                UPDATE teamrole
                SET TeamRoleName = %s
                WHERE TeamRoleID = %s
            """
            cur.execute(sql, (
                req_data.TeamRoleName,
                req_data.TeamRoleID,
            ))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Team role not found")

            con.commit()

        return {"msg": "Team role updated successfully", "TeamRoleID": req_data.TeamRoleID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def delete_teamrole(team_role_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "DELETE FROM teamrole WHERE TeamRoleID = %s"
            cur.execute(sql, (team_role_id,))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Team role not found")

            con.commit()

        return {"msg": "Team role deleted successfully", "TeamRoleID": team_role_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})
