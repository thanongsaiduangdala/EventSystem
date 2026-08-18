import pymysql
from fastapi import HTTPException, status
from DB.DBConnect import getConnect
from models.schema import AddPaymentTypeInfoRequest, UpdatePaymentTypeInfoRequest


async def create_paymenttype(req_data: AddPaymentTypeInfoRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                INSERT INTO paymenttypeinfo
                (PaymentTypeName)
                VALUES (%s)
            """
            cur.execute(sql, (
                req_data.PaymentTypeName,
            ))
            con.commit()
            PaymentType_ID = cur.lastrowid

        return {"msg": "Payment type created successfully", "PaymentTypeID": PaymentType_ID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_all_PaymentTypes():
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM paymenttypeinfo"
            cur.execute(sql)
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_paymenttype_by_id(payment_type_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM paymenttypeinfo WHERE PaymentTypeID = %s"
            cur.execute(sql, (payment_type_id,))
            row = cur.fetchone()

        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment type not found")

        return row

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def update_paymenttype(req_data: UpdatePaymentTypeInfoRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                UPDATE paymenttypeinfo
                SET PaymentTypeName = %s
                WHERE PaymentTypeID = %s
            """
            cur.execute(sql, (
                req_data.PaymentTypeName,
                req_data.PaymentTypeID,
            ))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment type not found")

            con.commit()

        return {"msg": "Payment type updated successfully", "PaymentTypeID": req_data.PaymentTypeID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def delete_paymenttype(payment_type_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "DELETE FROM paymenttypeinfo WHERE PaymentTypeID = %s"
            cur.execute(sql, (payment_type_id,))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment type not found")

            con.commit()

        return {"msg": "Payment type deleted successfully", "PaymentTypeID": payment_type_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})
