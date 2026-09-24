import os
import uuid
from datetime import datetime
import pymysql
from fastapi import HTTPException, UploadFile, File, Depends, status
from DB.DBConnect import getConnect
from models.schema import AddIdentityVerificationRequest, UpdateIdentityVerificationRequest
from auth.dependencies import require_employee_or_superadmin
from controllers.Event_Controllers.Notification_controllers import notify_accounts

# Relative to the backend's working directory / static file mount, matching
# the same "<baseUrl>/static/<path>" convention CategoryIconPath already uses.
DOCUMENT_UPLOAD_DIR = "static/identity_documents"
ALLOWED_DOCUMENT_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".heic", ".heif"}
MAX_DOCUMENT_BYTES = 10 * 1024 * 1024  # 10 MB


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


async def upload_identity_document(file: UploadFile = File(...)):
    """
    Accepts a camera photo or gallery image for a verification record's
    DocumentImageRedPath, saves it under the static file mount, and returns
    the relative path to store on the record (consumed by
    IdentityVerificationApiService.uploadDocumentImage on the Flutter side).
    """
    try:
        ext = os.path.splitext(file.filename or "")[1].lower()
        if ext not in ALLOWED_DOCUMENT_EXTENSIONS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Unsupported file type. Allowed: jpg, jpeg, png, webp, heic",
            )

        contents = await file.read()
        if len(contents) > MAX_DOCUMENT_BYTES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="File too large (max 10MB)",
            )

        os.makedirs(DOCUMENT_UPLOAD_DIR, exist_ok=True)
        new_filename = f"{uuid.uuid4().hex}{ext}"
        dest_path = os.path.join(DOCUMENT_UPLOAD_DIR, new_filename)

        with open(dest_path, "wb") as f:
            f.write(contents)

        relative_path = f"identity_documents/{new_filename}"
        return {"msg": "Document uploaded successfully", "path": relative_path}

    except HTTPException:
        raise
    except Exception as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"upload error": str(err)})


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


async def get_identityverifications_with_accounts(
    current=Depends(require_employee_or_superadmin),
):
    """
    Identity verification records joined with their account's basic details and
    the applicant's organization profile(s). Consumed by the Employee
    Dashboard -- pending reviews are listed first, then denied, then accepted,
    newest submissions on top. Each row includes an "Organizers" array built
    from eventorganizerinfo (matched by CreatedByAccountID), so the detail
    view can show organization info without needing extra permissions.
    """
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                SELECT iv.*, a.FirstName, a.LastName, a.Email, a.PhoneNum,
                       a.StatusID AS AccountStatusID
                FROM identityverification iv
                INNER JOIN accountinfo a ON a.AccountID = iv.AccountID
                ORDER BY FIELD(iv.VerificationStatusID, 1, 3, 2),
                         iv.SubmittedAtYMDT DESC
            """
            cur.execute(sql)
            rows = cur.fetchall()

            organizers_by_account = {}
            cur.execute(
                """
                SELECT *
                FROM eventorganizerinfo
                ORDER BY EventOrganizerName
                """
            )
            for org in cur.fetchall():
                organizers_by_account.setdefault(org["CreatedByAccountID"], []).append(org)

        for row in rows:
            row["Organizers"] = organizers_by_account.get(row["AccountID"], [])

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


def _review_identityverification(verfication_id: int, reviewer_account_id: int, new_status_id: int):
    """Shared review helper: marks a verification with the given status and
    records who reviewed it and when. Returns the verification's AccountID."""
    con = getConnect()
    try:
        with con.cursor() as cur:
            cur.execute(
                "SELECT AccountID FROM identityverification WHERE VerificationID = %s",
                (verfication_id,),
            )
            row = cur.fetchone()
            if row is None:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Identity verification not found")

            cur.execute(
                """
                UPDATE identityverification
                SET VerificationStatusID = %s,
                    ReviewedByAccountID = %s,
                    ReviewedAtYMDT = %s
                WHERE VerificationID = %s
                """,
                (new_status_id, reviewer_account_id, datetime.now(), verfication_id),
            )
            con.commit()
            return row["AccountID"]
    except HTTPException:
        con.rollback()
        raise
    except pymysql.MySQLError as err:
        con.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})
    finally:
        con.close()


async def approve_identityverification(
    verfication_id: int,
    current=Depends(require_employee_or_superadmin),
):
    """
    Employee/Superadmin action: accepts a pending organizer identity request
    (VerificationStatusID = 2) and grants the account ORGANIZER access
    (accountinfo.StatusID = 2) so they can create events right away.
    """
    try:
        account_id = _review_identityverification(verfication_id, current["account_id"], 2)

        con = getConnect()
        with con.cursor() as cur:
            cur.execute(
                "UPDATE accountinfo SET StatusID = 2 WHERE AccountID = %s",
                (account_id,),
            )
            con.commit()
            cur.execute(
                "SELECT CONCAT(FirstName, ' ', LastName) AS FullName "
                "FROM accountinfo WHERE AccountID = %s",
                (account_id,),
            )
            name_row = cur.fetchone()

        full_name = name_row["FullName"] if name_row else ""
        greeting = f", {full_name}" if full_name else ""
        notify_accounts(
            [account_id],
            "system",
            "Organizer application approved",
            f"Congratulations{greeting}! Your identity has been verified. "
            "Log out and log back in to access the Organizers Dashboard.",
        )

        return {"msg": "Identity verification approved and organizer access granted", "VerificationID": verfication_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def deny_identityverification(
    verfication_id: int,
    current=Depends(require_employee_or_superadmin),
):
    """Employee/Superadmin action: rejects a pending organizer identity request
    (VerificationStatusID = 3). The account is NOT changed."""
    try:
        account_id = _review_identityverification(verfication_id, current["account_id"], 3)
        notify_accounts(
            [account_id],
            "system",
            "Organizer application denied",
            "Your Become Organizer application was not approved. "
            "Review the details and submit a new application with correct "
            "information.",
        )
        return {"msg": "Identity verification denied", "VerificationID": verfication_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})