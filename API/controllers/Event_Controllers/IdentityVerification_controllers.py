import pymysql
from fastapi import HTTPException, status
from DB.DBConnect import getConnect
from models.schema import AddIdentityVerificationRequest, UpdateIdentityVerificationRequest


async def create_identityverification(req_data: AddIdentityVerificationRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                INSERT INTO identityverification
                (AccountID, VerificationTypeID, IDNumberEncrypted, FullNameOnID, DateOfBirth,
                 DocumentImageRedPath, VerificationStatusID, ReviewedByAccountID, SubmittedAtYMDT, ReviewedAtYMDT)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """
            cur.execute(sql, (
                req_data.AccountID,
                req_data.VerificationTypeID,
                req_data.IDNumberEncrypted,
                req_data.FullNameOnID,
                req_data.DateOfBirth,
                req_data.DocumentImageRedPath,
                req_data.VerificationStatusID,
                req_data.ReviewedByAccountID,
                req_data.SubmittedAtYMDT,
                req_data.ReviewedAtYMDT,
            ))
            con.commit()
            Verification_ID = cur.lastrowid

        return {"msg": "Identity verification created successfully", "VerificationID": Verification_ID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_all_identityverifications():
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM identityverification"
            cur.execute(sql)
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_identityverification_by_id(verfication_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM identityverification WHERE VerificationID = %s"
            cur.execute(sql, (verfication_id,))
            row = cur.fetchone()

        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Identity verification not found")

        return row

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_verified_accounts_for_organizer():
    """
    Accounts that have at least one identity verification record with
    VerificationStatusID == 2 (Accepted). Used to populate the "Created By"
    picker on the Event Organizer form so only verified accounts can be
    chosen, instead of the user typing a raw AccountID.
    """
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                SELECT DISTINCT a.AccountID, a.FirstName, a.LastName, a.Email
                FROM accountinfo a
                INNER JOIN identityverification iv ON iv.AccountID = a.AccountID
                WHERE iv.VerificationStatusID = 2
                ORDER BY a.FirstName, a.LastName
            """
            cur.execute(sql)
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_identityverifications_by_account_id(account_id: int):
    """Convenience lookup: all verification records submitted by a given AccountID."""
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM identityverification WHERE AccountID = %s"
            cur.execute(sql, (account_id,))
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def update_identityverification(req_data: UpdateIdentityVerificationRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                UPDATE identityverification
                SET AccountID = %s,
                    VerificationTypeID = %s,
                    IDNumberEncrypted = %s,
                    FullNameOnID = %s,
                    DateOfBirth = %s,
                    DocumentImageRedPath = %s,
                    VerificationStatusID = %s,
                    ReviewedByAccountID = %s,
                    SubmittedAtYMDT = %s,
                    ReviewedAtYMDT = %s
                WHERE VerificationID = %s
            """
            cur.execute(sql, (
                req_data.AccountID,
                req_data.VerificationTypeID,
                req_data.IDNumberEncrypted,
                req_data.FullNameOnID,
                req_data.DateOfBirth,
                req_data.DocumentImageRedPath,
                req_data.VerificationStatusID,
                req_data.ReviewedByAccountID,
                req_data.SubmittedAtYMDT,
                req_data.ReviewedAtYMDT,
                req_data.VerificationID,
            ))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Identity verification not found")

            con.commit()

        return {"msg": "Identity verification updated successfully", "VerificationID": req_data.VerificationID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def delete_identityverification(verfication_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "DELETE FROM identityverification WHERE VerificationID = %s"
            cur.execute(sql, (verfication_id,))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Identity verification not found")

            con.commit()

        return {"msg": "Identity verification deleted successfully", "VerificationID": verfication_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})