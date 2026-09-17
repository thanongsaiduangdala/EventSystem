import pymysql
from fastapi import HTTPException, status
from DB.DBConnect import getConnect
from models.schema import AddAccountStatusInfoRequest, UpdateAccountStatusInfoRequest


async def create_accountstatusinfo(req_data: AddAccountStatusInfoRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                INSERT INTO accountstatusinfo
                (StatusType)
                VALUES (%s)
            """
            cur.execute(sql, (
                req_data.StatusType,
            ))
            con.commit()
            StatusID = cur.lastrowid

        return {"msg": "Account status created successfully", "Status ID": StatusID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_all_accountstatusinfo():
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM accountstatusinfo"
            cur.execute(sql)
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_accountstatusinfo_by_id(status_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM accountstatusinfo WHERE StatusID = %s"
            cur.execute(sql, (status_id,))
            row = cur.fetchone()

        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Status ID not found")

        return row

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})
    

async def update_accountstatusinfo(req_data: UpdateAccountStatusInfoRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                UPDATE accountstatusinfo
                SET StatusType = %s
                WHERE StatusID = %s
            """
            cur.execute(sql, (
                req_data.StatusType,
                req_data.StatusID,
            ))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Account Status not found")

            con.commit()

        return {"msg": "Account status updated successfully", "StatusID": req_data.StatusID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def delete_accountstatus(status_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "DELETE FROM accountstatusinfo WHERE StatusID = %s"
            cur.execute(sql, (status_id,))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Account status not found")

            con.commit()

        return {"msg": "Account status deleted successfully", "StatusID": status_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})
