import pymysql
from fastapi import HTTPException, status
from DB.DBConnect import getConnect
from models.schema import AddEventRoleRequest, UpdateEventRoleRequest


async def create_eventrole(req_data: AddEventRoleRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                INSERT INTO eventRole
                (RoleName)
                VALUES (%s)
            """
            cur.execute(sql, (
                req_data.RoleName,
            ))
            con.commit()
            EventRole_ID = cur.lastrowid

        return {"msg": "Event role created successfully", "EventRoleID": EventRole_ID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_all_EventRoles():
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM eventRole"
            cur.execute(sql)
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_eventrole_by_id(event_role_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM eventRole WHERE EventRoleID = %s"
            cur.execute(sql, (event_role_id,))
            row = cur.fetchone()

        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event role not found")

        return row

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def update_eventrole(req_data: UpdateEventRoleRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                UPDATE eventRole
                SET RoleName = %s
                WHERE EventRoleID = %s
            """
            cur.execute(sql, (
                req_data.RoleName,
                req_data.EventRoleID,
            ))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event role not found")

            con.commit()

        return {"msg": "Event role updated successfully", "EventRoleID": req_data.EventRoleID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def delete_eventrole(event_role_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "DELETE FROM eventRole WHERE EventRoleID = %s"
            cur.execute(sql, (event_role_id,))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event role not found")

            con.commit()

        return {"msg": "Event role deleted successfully", "EventRoleID": event_role_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})
