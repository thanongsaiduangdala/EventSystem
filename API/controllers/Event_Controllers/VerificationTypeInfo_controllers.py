import pymysql
from fastapi import HTTPException, status
from DB.DBConnect import getConnect
from models.schema import AddVerificationTypeInfoRequest, UpdateVerificationTypeInfoRequest


async def create_Verificationtype(req_data: AddVerificationTypeInfoRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                INSERT INTO verificationtypeinfo
                (IDType)
                VALUES (%s)
            """
            cur.execute(sql, (
                req_data.IDType,
            ))
            con.commit()
            VerificationType_ID = cur.lastrowid

        return {"msg": "Verification type created successfully", "VerificationTypeID": VerificationType_ID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_all_VerificationTypes():
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM verificationtypeinfo"
            cur.execute(sql)
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_Verificationtype_by_id(Verification_type_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM verificationtypeinfo WHERE VerificationTypeID = %s"
            cur.execute(sql, (Verification_type_id,))
            row = cur.fetchone()

        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Verification type not found")

        return row

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def update_Verificationtype(req_data: UpdateVerificationTypeInfoRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                UPDATE verificationtypeinfo
                SET IDType = %s
                WHERE VerificationTypeID = %s
            """
            cur.execute(sql, (
                req_data.IDType,
                req_data.VerificationTypeID,
            ))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Verification type not found")

            con.commit()

        return {"msg": "Verification type updated successfully", "VerificationTypeID": req_data.VerificationTypeID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def delete_Verificationtype(Verification_type_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "DELETE FROM verificationtypeinfo WHERE VerificationTypeID = %s"
            cur.execute(sql, (Verification_type_id,))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Verification type not found")

            con.commit()

        return {"msg": "Verification type deleted successfully", "VerificationTypeID": Verification_type_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})