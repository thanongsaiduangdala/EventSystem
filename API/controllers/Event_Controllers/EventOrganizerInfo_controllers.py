import os
import uuid
import pymysql
from fastapi import HTTPException, status, Depends, UploadFile, File, Form
from DB.DBConnect import getConnect
from models.schema import AddEventOrganizerInfoRequest, UpdateEventOrganizerInfoRequest
from auth.dependencies import require_developer

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


async def create_eventorganizer(req_data: AddEventOrganizerInfoRequest, current=Depends(require_developer)):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                INSERT INTO eventorganizerInfo
                (EventOrganizerName, EventOrganizerLogoPath, CreatedByAccountID, EventOrganizerDiscription)
                VALUES (%s, %s, %s, %s)
            """
            cur.execute(sql, (
                req_data.EventOrganizerName,
                req_data.EventOrganizerLogoPath,
                req_data.CreatedByAccountID,
                req_data.EventOrganizerDiscription,
            ))
            con.commit()
            EventOrganizer_ID = cur.lastrowid

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
    current=Depends(require_developer),
):
    """Creates a new organizer with a logo file sent directly (multipart) --
    same shape as SponserApiService.uploadSponser."""
    try:
        logo_path = _save_logo_file(logo)

        con = getConnect()
        with con.cursor() as cur:
            sql = """
                INSERT INTO eventorganizerInfo
                (EventOrganizerName, EventOrganizerLogoPath, CreatedByAccountID, EventOrganizerDiscription)
                VALUES (%s, %s, %s, %s)
            """
            cur.execute(sql, (
                EventOrganizerName,
                logo_path,
                CreatedByAccountID,
                EventOrganizerDiscription,
            ))
            con.commit()
            EventOrganizer_ID = cur.lastrowid

        return {"msg": "Event organizer created successfully", "EventOrganizer_ID": EventOrganizer_ID}

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
    current=Depends(require_developer),
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
                    "SELECT EventOrganizerLogoPath FROM eventorganizerInfo WHERE EventOrganizerID = %s",
                    (EventOrganizerID,),
                )
                row = cur.fetchone()
            if row is None:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event organizer not found")
            logo_path = row["EventOrganizerLogoPath"]

        with con.cursor() as cur:
            sql = """
                UPDATE eventorganizerInfo
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


async def get_all_EventOrganizers(current=Depends(require_developer)):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM eventorganizerInfo"
            cur.execute(sql)
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_eventorganizer_by_id(event_organizer_id: int, current=Depends(require_developer)):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM eventorganizerInfo WHERE EventOrganizerID = %s"
            cur.execute(sql, (event_organizer_id,))
            row = cur.fetchone()

        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event organizer not found")

        return row

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def update_eventorganizer(req_data: UpdateEventOrganizerInfoRequest,current=Depends(require_developer)):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                UPDATE eventorganizerInfo
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


async def delete_eventorganizer(event_organizer_id: int,current=Depends(require_developer)):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "DELETE FROM eventorganizerInfo WHERE EventOrganizerID = %s"
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