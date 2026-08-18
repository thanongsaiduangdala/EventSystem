import pymysql
from fastapi import HTTPException, status
from DB.DBConnect import getConnect
from models.schema import AddVerificationStatusInfoRequest, UpdateVerificationStatusInfoRequest


async def create_Verificationstatus(req_data: AddVerificationStatusInfoRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                INSERT INTO verificationstatusinfo
                (StatusName)
                VALUES (%s)
            """
            cur.execute(sql, (
                req_data.StatusName,
            ))
            con.commit()
            VerificationStatus_ID = cur.lastrowid

        return {"msg": "Verification status created successfully", "VerificationStatusID": VerificationStatus_ID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_all_VerificationStatuses():
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM verificationstatusinfo"
            cur.execute(sql)
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_Verificationstatus_by_id(verification_status_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM verificationstatusinfo WHERE VerificationStatusID = %s"
            cur.execute(sql, (verification_status_id,))
            row = cur.fetchone()

        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Verification status not found")

        return row

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def update_Verificationstatus(req_data: UpdateVerificationStatusInfoRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                UPDATE verificationstatusinfo
                SET StatusName = %s
                WHERE VerificationStatusID = %s
            """
            cur.execute(sql, (
                req_data.StatusName,
                req_data.VerificationStatusID,
            ))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Verification status not found")

            con.commit()

        return {"msg": "Verification status updated successfully", "VerificationStatusID": req_data.VerificationStatusID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def delete_Verificationstatus(verification_status_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "DELETE FROM verificationstatusinfo WHERE VerificationStatusID = %s"
            cur.execute(sql, (verification_status_id,))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Verification status not found")

            con.commit()

        return {"msg": "Verification status deleted successfully", "VerificationStatusID": verification_status_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})