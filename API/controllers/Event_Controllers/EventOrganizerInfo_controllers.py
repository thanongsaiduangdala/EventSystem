import os
import uuid
import pymysql
from fastapi import HTTPException, status, Depends, UploadFile, File, Form
from DB.DBConnect import getConnect
from models.schema import (
    AddEventOrganizerInfoRequest, UpdateEventOrganizerInfoRequest, DenyOrganizerRequest,
)
from auth.dependencies import (
    require_permission, get_current_account, require_employee_or_superadmin
)
from controllers.Event_Controllers.Notification_controllers import (
    notify_accounts, staff_account_ids
)
from realtime.review_events import publish_review_change

ORG_PENDING, ORG_APPROVED, ORG_DENIED = 1, 2, 3
MAX_DENY_REASON_LENGTH = 1000

# Mirrors the sponsor logo upload convention: files land in static/<subfolder>,
# and the DB stores the path relative to that -- fullImageUrl() on the Flutter
# side turns it back into "$baseUrl/static/<path>".
LOGO_DIR = os.path.join("static", "organizer_logos")


def _save_logo_file(upload: UploadFile) -> str:
    os.makedirs(LOGO_DIR, exist_ok=True)
    ext = os.path.splitext(upload.filename or "")[1] or ".jpg"
    unique_name = f"{uuid.uuid4().hex}{ext}"
    dest_path = os.path.join(LOGO_DIR, unique_name)
    with open(dest_path, "wb") as f:
        f.write(upload.file.read())
    # Store forward-slash relative path (matches fullImageUrl's "$baseUrl/static/$path")
    return f"organizer_logos/{unique_name}"


async def create_eventorganizer(req_data: AddEventOrganizerInfoRequest, current=Depends(require_permission("manage_event_organizer"))):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                INSERT INTO eventorganizerinfo
                (EventOrganizerName, EventOrganizerLogoPath, CreatedByAccountID, EventOrganizerDiscription)
                VALUES (%s, %s, %s, %s)
            """
            cur.execute(sql, (
                req_data.EventOrganizerName,
                req_data.EventOrganizerLogoPath,
                req_data.CreatedByAccountID,
                req_data.EventOrganizerDiscription,
            ))
            EventOrganizer_ID = cur.lastrowid
            con.commit()

        return {"msg": "Event organizer created successfully", "EventOrganizerID": EventOrganizer_ID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def upload_eventorganizer(
    EventOrganizerName: str = Form(...),
    CreatedByAccountID: int = Form(...),
    EventOrganizerDiscription: str | None = Form(None),
    logo: UploadFile = File(...),
    current=Depends(require_permission("manage_event_organizer")),
):
    """Creates a new organizer with a logo file sent directly (multipart) --
    same shape as SponserApiService.uploadSponser."""
    try:
        logo_path = _save_logo_file(logo)

        con = getConnect()
        with con.cursor() as cur:
            sql = """
                INSERT INTO eventorganizerinfo
                (EventOrganizerName, EventOrganizerLogoPath, CreatedByAccountID, EventOrganizerDiscription)
                VALUES (%s, %s, %s, %s)
            """
            cur.execute(sql, (
                EventOrganizerName,
                logo_path,
                CreatedByAccountID,
                EventOrganizerDiscription,
            ))
            EventOrganizer_ID = cur.lastrowid
            con.commit()

        return {"msg": "Event organizer created successfully", "EventOrganizer_ID": EventOrganizer_ID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def apply_eventorganizer(
    EventOrganizerName: str = Form(...),
    CreatedByAccountID: int = Form(...),
    EventOrganizerDiscription: str | None = Form(None),
    logo: UploadFile = File(...),
    current=Depends(get_current_account),
):
    """Self-service "become an organizer" application. Any logged-in user may
    create an organizer profile for their OWN account while their identity
    verification is pending -- no `manage_event_organizer` permission needed
    (that permission only kicks in after they are approved to be an
    ORGANIZER). Rejects the request if the account already has a profile."""
    try:
        if current["account_id"] != CreatedByAccountID:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You can only create an organizer profile for your own account",
            )

        con = getConnect()
        with con.cursor() as cur:
            cur.execute(
                "SELECT COUNT(*) AS cnt FROM eventorganizerinfo WHERE CreatedByAccountID = %s",
                (CreatedByAccountID,),
            )
            row = cur.fetchone()
        if row is not None and row["cnt"] > 0:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="You already have an organizer profile",
            )

        logo_path = _save_logo_file(logo)

        with con.cursor() as cur:
            # New applications start Pending (OrganizerStatusID = 1) until an
            # employee / superadmin approves the organization.
            sql = """
                INSERT INTO eventorganizerinfo
                (EventOrganizerName, EventOrganizerLogoPath, CreatedByAccountID,
                 EventOrganizerDiscription, OrganizerStatusID)
                VALUES (%s, %s, %s, %s, 1)
            """
            cur.execute(sql, (
                EventOrganizerName,
                logo_path,
                CreatedByAccountID,
                EventOrganizerDiscription,
            ))
            EventOrganizer_ID = cur.lastrowid
            con.commit()

            cur.execute(
                "SELECT CONCAT(FirstName, ' ', LastName) AS FullName "
                "FROM accountinfo WHERE AccountID = %s",
                (CreatedByAccountID,),
            )
            name_row = cur.fetchone()

        full_name = name_row["FullName"] if name_row else "Someone"
        notify_accounts(
            staff_account_ids(),
            "system",
            "New organizer application",
            f"{full_name} submitted a Become Organizer application for "
            f"'{EventOrganizerName}'. Review the organization in the Employee "
            "Dashboard (Organizations tab).",
            link=f"org_review:{EventOrganizer_ID}",
        )
        await publish_review_change(
            kind="organization", item_id=EventOrganizer_ID, status_id=ORG_PENDING,
            owner_account_id=CreatedByAccountID,
        )

        return {"msg": "Event organizer application received", "EventOrganizerID": EventOrganizer_ID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


def _review_eventorganizer(organizer_id: int, new_status_id: int, reason: str | None = None):
    """Moves a PENDING organization to Approved / Denied and returns
    (CreatedByAccountID, EventOrganizerName) so the owner can be notified.

    The write is `WHERE OrganizerStatusID = Pending`, so when two reviewers
    act on the same organization only the first one wins; the other gets a
    409 instead of silently overwriting the first decision.
    """
    con = getConnect()
    with con.cursor() as cur:
        cur.execute(
            "UPDATE eventorganizerinfo SET OrganizerStatusID = %s, DenyReason = %s "
            "WHERE EventOrganizerID = %s AND OrganizerStatusID = %s",
            (new_status_id, reason if new_status_id == ORG_DENIED else None,
             organizer_id, ORG_PENDING),
        )
        changed = cur.rowcount
        con.commit()

        cur.execute(
            "SELECT CreatedByAccountID, EventOrganizerName, OrganizerStatusID "
            "FROM eventorganizerinfo WHERE EventOrganizerID = %s",
            (organizer_id,),
        )
        row = cur.fetchone()

    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event organizer not found")
    if changed == 0:
        decided = {ORG_APPROVED: "approved", ORG_DENIED: "denied"}.get(row["OrganizerStatusID"], "reviewed")
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"This organization was already {decided} by another reviewer. "
                   "The list has been refreshed.",
        )
    return row["CreatedByAccountID"], row["EventOrganizerName"]


async def approve_eventorganizer(
    event_organizer_id: int,
    current=Depends(require_employee_or_superadmin),
):
    """Employee/Superadmin action: approves a pending organization
    (OrganizerStatusID = 2) so it becomes visible and usable."""
    try:
        owner_id, org_name = _review_eventorganizer(event_organizer_id, ORG_APPROVED)
        notify_accounts(
            [owner_id],
            "system",
            "Organization approved",
            f"Your organization '{org_name}' has been approved. You can now "
            "create events and build your team.",
        )
        await publish_review_change(
            kind="organization", item_id=event_organizer_id, status_id=ORG_APPROVED,
            owner_account_id=owner_id,
        )
        return {"msg": "Organization approved", "EventOrganizerID": event_organizer_id}
    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def deny_eventorganizer(
    event_organizer_id: int,
    req_data: DenyOrganizerRequest,
    current=Depends(require_employee_or_superadmin),
):
    """Employee/Superadmin action: rejects a pending organization
    (OrganizerStatusID = 3). A reason is required; the owner sees it and has
    to fix the organization and press Save to send it for review again."""
    reason = (req_data.Reason or "").strip()
    if not reason:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Please give a reason when denying an organization.",
        )
    if len(reason) > MAX_DENY_REASON_LENGTH:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"The reason is too long (max {MAX_DENY_REASON_LENGTH} characters).",
        )
    try:
        owner_id, org_name = _review_eventorganizer(event_organizer_id, ORG_DENIED, reason)
        notify_accounts(
            [owner_id],
            "system",
            "Organization not approved",
            f"Your organization '{org_name}' was not approved.\n"
            f"Reason: {reason}\n"
            "Please fix it, then open your organization page and press Save "
            "to send it for review again.",
        )
        await publish_review_change(
            kind="organization", item_id=event_organizer_id, status_id=ORG_DENIED,
            owner_account_id=owner_id, deny_reason=reason,
        )
        return {"msg": "Organization denied", "EventOrganizerID": event_organizer_id}
    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def resubmit_eventorganizer(
    EventOrganizerID: int = Form(...),
    EventOrganizerName: str = Form(...),
    EventOrganizerDiscription: str | None = Form(None),
    logo: UploadFile | None = File(None),
    current=Depends(get_current_account),
):
    """The owner's "Save" after a denial: updates the organization and puts it
    back to Pending so reviewers look at it again. Only the owner can do it,
    and only while the organization is Denied."""
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute(
                "SELECT CreatedByAccountID, EventOrganizerLogoPath, OrganizerStatusID "
                "FROM eventorganizerinfo WHERE EventOrganizerID = %s",
                (EventOrganizerID,),
            )
            row = cur.fetchone()
        if row is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event organizer not found")
        if row["CreatedByAccountID"] != current["account_id"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only the owner of this organization can resubmit it",
            )
        if row["OrganizerStatusID"] != ORG_DENIED:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="This organization is not denied, so there is nothing to resubmit.",
            )

        logo_path = _save_logo_file(logo) if logo is not None else row["EventOrganizerLogoPath"]

        with con.cursor() as cur:
            cur.execute(
                """
                UPDATE eventorganizerinfo
                SET EventOrganizerName = %s,
                    EventOrganizerLogoPath = %s,
                    EventOrganizerDiscription = %s,
                    OrganizerStatusID = %s,
                    DenyReason = NULL
                WHERE EventOrganizerID = %s AND OrganizerStatusID = %s
                """,
                (EventOrganizerName, logo_path, EventOrganizerDiscription,
                 ORG_PENDING, EventOrganizerID, ORG_DENIED),
            )
            changed = cur.rowcount
            con.commit()
        if changed == 0:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="This organization changed while you were editing. Please reload.",
            )

        notify_accounts(
            staff_account_ids(),
            "system",
            "Organization resubmitted",
            f"'{EventOrganizerName}' was edited after being denied and is "
            "pending approval again.",
            link=f"org_review:{EventOrganizerID}",
        )
        await publish_review_change(
            kind="organization", item_id=EventOrganizerID, status_id=ORG_PENDING,
            owner_account_id=row["CreatedByAccountID"],
        )
        return {"msg": "Organization resubmitted for approval", "EventOrganizerID": EventOrganizerID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def replace_eventorganizer_logo(
    EventOrganizerID: int = Form(...),
    EventOrganizerName: str = Form(...),
    CreatedByAccountID: int = Form(...),
    EventOrganizerDiscription: str | None = Form(None),
    logo: UploadFile | None = File(None),
    current=Depends(require_permission("manage_event_organizer")),
):
    """Updates an existing organizer's fields and, if provided, swaps its
    logo file -- same shape as SponserApiService.replaceSponserLogo."""
    try:
        con = getConnect()

        if logo is not None:
            logo_path = _save_logo_file(logo)
        else:
            with con.cursor() as cur:
                cur.execute(
                    "SELECT EventOrganizerLogoPath FROM eventorganizerinfo WHERE EventOrganizerID = %s",
                    (EventOrganizerID,),
                )
                row = cur.fetchone()
            if row is None:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event organizer not found")
            logo_path = row["EventOrganizerLogoPath"]

        with con.cursor() as cur:
            sql = """
                UPDATE eventorganizerinfo
                SET EventOrganizerName = %s,
                    EventOrganizerLogoPath = %s,
                    CreatedByAccountID = %s,
                    EventOrganizerDiscription = %s
                WHERE EventOrganizerID = %s
            """
            cur.execute(sql, (
                EventOrganizerName,
                logo_path,
                CreatedByAccountID,
                EventOrganizerDiscription,
                EventOrganizerID,
            ))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event organizer not found")

            con.commit()

        return {"msg": "Event organizer updated successfully", "EventOrganizerID": EventOrganizerID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_all_EventOrganizers(current=Depends(require_permission("view_events"))):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM eventorganizerinfo"
            cur.execute(sql)
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_eventorganizer_by_id(event_organizer_id: int, current=Depends(require_permission("view_events"))):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM eventorganizerinfo WHERE EventOrganizerID = %s"
            cur.execute(sql, (event_organizer_id,))
            row = cur.fetchone()

        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event organizer not found")

        return row

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def update_eventorganizer(req_data: UpdateEventOrganizerInfoRequest,current=Depends(require_permission("manage_event_organizer"))):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                UPDATE eventorganizerinfo
                SET EventOrganizerName = %s,
                    EventOrganizerLogoPath = %s,
                    CreatedByAccountID = %s,
                    EventOrganizerDiscription = %s
                WHERE EventOrganizerID = %s
            """
            cur.execute(sql, (
                req_data.EventOrganizerName,
                req_data.EventOrganizerLogoPath,
                req_data.CreatedByAccountID,
                req_data.EventOrganizerDiscription,
                req_data.EventOrganizerID,
            ))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event organizer not found")

            con.commit()

        return {"msg": "Event organizer updated successfully", "EventOrganizerID": req_data.EventOrganizerID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def delete_eventorganizer(event_organizer_id: int,current=Depends(require_permission("manage_event_organizer"))):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "DELETE FROM eventorganizerinfo WHERE EventOrganizerID = %s"
            cur.execute(sql, (event_organizer_id,))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event organizer not found")

            con.commit()

        return {"msg": "Event organizer deleted successfully", "EventOrganizerID": event_organizer_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})
