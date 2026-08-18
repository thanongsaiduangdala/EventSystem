import pymysql
import bcrypt
from fastapi import HTTPException, status
from DB.DBConnect import getConnect
from models.schema import AddAccountInfoRequest, UpdateAccountNoPasswordInfoRequest

async def create_account(req_data: AddAccountInfoRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:

            pwd_byte = req_data.PasswordEnc.encode("utf-8")
            salt = bcrypt.gensalt(rounds=10)
            hash_pwd = bcrypt.hashpw(pwd_byte, salt).decode("utf-8")

            sql = """
                INSERT INTO accountinfo
                (FirstName, LastName, PhoneNum, Email, StatusID, PasswordEnc)
                VALUES (%s, %s, %s, %s, %s, %s)
            """
            cur.execute(sql, (
                req_data.FirstName,
                req_data.LastName,
                req_data.PhoneNum,
                req_data.Email,
                req_data.StatusID,
                hash_pwd
            ))
            con.commit()
            account_id = cur.lastrowid

        return {"msg": "Account created successfully", "account_id": account_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_all_accounts():
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("""
                SELECT * FROM accountinfo
            """)
            Accounts = cur.fetchall()

        return {"Accounts": Accounts}

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_account_by_id(account_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("""
                SELECT * FROM accountinfo WHERE AccountID = %s
            """, (account_id,))
            Accounts = cur.fetchone()

        if Accounts is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Account not found")

        return {"Account": Accounts}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def update_account(req_data: UpdateAccountNoPasswordInfoRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                UPDATE accountinfo
                SET FirstName = %s,
                    LastName = %s,
                    PhoneNum = %s,
                    Email = %s,
                    StatusID = %s
                WHERE AccountID = %s
            """
            cur.execute(sql, (
                req_data.FirstName,
                req_data.LastName,
                req_data.PhoneNum,
                req_data.Email,
                req_data.StatusID,
                req_data.AccountID
            ))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Account not found")

            con.commit()

        return {"msg": "account updated successfully", "account_id": req_data.AccountID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def delete_account(account_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("DELETE FROM accountinfo WHERE AccountID = %s", (account_id,))
            rows_deleted = cur.rowcount
            con.commit()

        if rows_deleted == 0:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Account not found")

        return {"msg": "Account deleted successfully", "account_id": account_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})