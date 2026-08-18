import random
import string
import time
import bcrypt
import pymysql
from fastapi import HTTPException, status, Depends
from DB.DBConnect import getConnect
from models.schema import (
    SignUpRequest, LoginRequest, SendOtpRequest,
    ResetPasswordRequest, SignupOtpRequest, VerifyOtpRequest,
)
from controllers.email_service_controller import (
    send_otp_email, forgot_otp_store, signup_otp_store,
)
from auth.jwt_handler import create_access_token
from auth.dependencies import require_developer

OTP_TTL_SECONDS = 300  


def _store_otp(store: dict, email: str, otp: str) -> None:
    store[email] = {"otp": otp, "expires_at": time.time() + OTP_TTL_SECONDS}
    


def _check_otp(store: dict, email: str, otp: str) -> None:
    """Raises HTTPException if the OTP is missing, expired, or incorrect."""
    stored = store.get(email)
    if stored is None or time.time() > stored["expires_at"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="OTP expired or not found. Please request a new code.",
        )
    if stored["otp"] != otp:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid OTP")


async def signup(req_data: SignUpRequest):
    try:
        _check_otp(signup_otp_store, req_data.email, req_data.otp)

        pwd_byte = req_data.password.encode("utf-8")
        salt = bcrypt.gensalt(rounds=10)
        hash_pwd = bcrypt.hashpw(pwd_byte, salt).decode("utf-8")


        con = getConnect()
        with con.cursor() as cur:
            sql = """
                INSERT INTO accountinfo
                (FirstName, LastName, PhoneNum, Email, StatusID, PasswordEnc)
                VALUES (%s, %s, %s, %s, %s, %s)
            """
            cur.execute(sql, (req_data.firstname, req_data.lastname, req_data.phonenum, req_data.email, 1, hash_pwd))
            con.commit()
            account_id = cur.lastrowid

        del signup_otp_store[req_data.email]

        return {"msg": "SignUp Success", "account_id": account_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def login(req_data: LoginRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                SELECT AccountID, FirstName, LastName,
                       PhoneNum, Email, StatusID, PasswordEnc
                FROM accountinfo
                WHERE Email = %s
            """
            cur.execute(sql, (req_data.email,))
            user = cur.fetchone()

        if user is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Email not found")

        is_match = bcrypt.checkpw(req_data.password.encode("utf-8"), user["PasswordEnc"].encode("utf-8"))
        print("Match result:", is_match)

        if not is_match:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect password")

        if user["StatusID"] == 4:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is not active")

        token = create_access_token(account_id=user["AccountID"], status_id=user["StatusID"])

        return {
            "msg": "Login Success",
            "access_token": token,
            "token_type": "bearer",
            "AccountID": user["AccountID"],
            "StatusID": user["StatusID"],
            "firstname": user["FirstName"],
            "lastname": user["LastName"],
            "PhoneNum": user["PhoneNum"],
            "Email": user["Email"]
        }

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def send_forgot_otp(req_data: SendOtpRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute(
                "SELECT AccountID FROM accountinfo WHERE Email = %s AND (StatusID = 1 OR StatusID = 2 OR StatusID = 3)",
                (req_data.email,)
            )
            user = cur.fetchone()

        if user is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Email not found")

        otp = ''.join(random.choices(string.digits, k=6))
        _store_otp(forgot_otp_store, req_data.email, otp)
        print(f"OTP for {req_data.email}: {otp}")

        send_otp_email(req_data.email, otp)

        return {"msg": "OTP sent successfully"}

    except HTTPException:
        raise
    except Exception as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"error": str(err)})


async def reset_password(req_data: ResetPasswordRequest):
    try:
        _check_otp(forgot_otp_store, req_data.email, req_data.otp)

        pwd_byte = req_data.new_password.encode("utf-8")
        salt = bcrypt.gensalt(rounds=10)
        hash_pwd = bcrypt.hashpw(pwd_byte, salt).decode("utf-8")

        con = getConnect()
        with con.cursor() as cur:
            sql = """
                UPDATE accountinfo
                SET PasswordEnc = %s
                WHERE Email = %s
            """
            cur.execute(sql, (hash_pwd, req_data.email))
            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Account not found")
            con.commit()

        del forgot_otp_store[req_data.email]

        return {"msg": "Password reset successfully"}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def send_signup_otp(req_data: SignupOtpRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("SELECT AccountID FROM accountinfo WHERE Email = %s", (req_data.email,))
            existing = cur.fetchone()

        if existing is not None:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")

        otp = ''.join(random.choices(string.digits, k=6))
        _store_otp(signup_otp_store, req_data.email, otp)
        print(f"Signup OTP for {req_data.email}: {otp}")

        send_otp_email(req_data.email, otp)

        return {"msg": "OTP sent successfully"}

    except HTTPException:
        raise
    except Exception as err:
        print(f"GENERAL ERROR: {err}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Error: {str(err)}")


async def verify_otp(req_data: VerifyOtpRequest):
    try:
        _check_otp(forgot_otp_store, req_data.email, req_data.otp)
        return {"msg": "OTP verified"}
    except HTTPException:
        raise
    except Exception as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"error": str(err)})

async def get_account_status(account_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("SELECT StatusID FROM accountinfo WHERE AccountID = %s", (account_id,))
            row = cur.fetchone()

        if row is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Account not found")

        return {"StatusID": row["StatusID"]}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})

async def check_developer_status(current=Depends(require_developer)):
    return {"msg": "Developer access confirmed", "AccountID": current["account_id"]}