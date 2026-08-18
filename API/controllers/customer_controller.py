import pymysql
from fastapi import HTTPException, status
from DB.DBConnect import getConnect
from models.schema import DeleteCustomerRequest, CheckDuplicateRequest


async def delete_customer(req_data: DeleteCustomerRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("DELETE FROM accountinfo WHERE AccountID = %s", (req_data.account_id,))
            rows_deleted = cur.rowcount
            con.commit()

            if rows_deleted == 0:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Account not found")

        return {"msg": "Account deleted successfully", "account_id": req_data.account_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def check_duplicate(req_data: CheckDuplicateRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute(
                "SELECT Email, PhoneNum FROM accountinfo WHERE Email = %s OR PhoneNum = %s",
                (req_data.email, req_data.phonenum)
            )
            existing = cur.fetchone()

        if existing is None:
            return {"msg": "OK"}

        if existing["Email"] == req_data.email:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email")
        if existing["PhoneNum"] == req_data.phonenum:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="PhoneNum")

        return {"msg": "OK"}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})