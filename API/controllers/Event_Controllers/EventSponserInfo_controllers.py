import os
import uuid
import pymysql
import aiofiles
from fastapi import HTTPException, status, UploadFile, File, Form
from typing import Optional
from DB.DBConnect import getConnect
from models.schema import AddSponserInfoRequest, UpdateSponserInfoRequest, AddEventSponserInfoRequest, UpdateEventSponserInfoRequest

# Where sponsor logo files get written to disk. Adjust this to match wherever
# your event-image uploads are already being stored/served from (e.g. if you
# already mount a "static" folder in main.py, keep this consistent with it).
SPONSOR_LOGO_DIR = "static/sponsor_logos"
os.makedirs(SPONSOR_LOGO_DIR, exist_ok=True)


async def _save_logo_file(file: UploadFile) -> str:
    ext = os.path.splitext(file.filename or "")[1] or ".jpg"
    filename = f"{uuid.uuid4().hex}{ext}"
    filepath = os.path.join(SPONSOR_LOGO_DIR, filename)
    content = await file.read()
    async with aiofiles.open(filepath, "wb") as out_file:
        await out_file.write(content)
    # Path returned to the client / stored in DB, relative to the static root.
    return f"sponsor_logos/{filename}"


async def create_sponser(req_data: AddSponserInfoRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                INSERT INTO sponserinfo
                (SponserName,SponserLogoPath)
                VALUES (%s, %s)
            """
            cur.execute(sql, (
                req_data.SponserName,
                req_data.SponserLogoPath
            ))
            con.commit()
            Sponser_ID = cur.lastrowid

        return {"msg": "Event created successfully", "Sponser_ID": Sponser_ID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


#----------------------------------------------------------------------------------------------------------------------
# NEW: multipart endpoints so the Flutter app can send the logo bytes directly
# instead of having to upload the file somewhere else first and pass a path.
#----------------------------------------------------------------------------------------------------------------------

async def upload_sponser(
    SponserName: str = Form(...),
    logo: UploadFile = File(...),
):
    try:
        logo_path = await _save_logo_file(logo)

        con = getConnect()
        with con.cursor() as cur:
            sql = """
                INSERT INTO sponserinfo
                (SponserName,SponserLogoPath)
                VALUES (%s, %s)
            """
            cur.execute(sql, (SponserName, logo_path))
            con.commit()
            Sponser_ID = cur.lastrowid

        return {
            "msg": "Sponsor created successfully",
            "Sponser_ID": Sponser_ID,
            "SponserLogoPath": logo_path,
        }

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def replace_sponser_logo(
    SponserID: int = Form(...),
    SponserName: str = Form(...),
    logo: Optional[UploadFile] = File(None),
):
    try:
        con = getConnect()

        if logo is not None:
            logo_path = await _save_logo_file(logo)
        else:
            # No new file: keep whatever path is already stored.
            with con.cursor() as cur:
                cur.execute(
                    "SELECT SponserLogoPath FROM sponserinfo WHERE SponserID = %s",
                    (SponserID,),
                )
                row = cur.fetchone()
                if row is None:
                    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sponsor not found")
                logo_path = row["SponserLogoPath"] if isinstance(row, dict) else row[1]

        with con.cursor() as cur:
            sql = """
                UPDATE sponserinfo
                SET SponserName = %s,
                    SponserLogoPath = %s
                WHERE SponserID = %s
            """
            cur.execute(sql, (SponserName, logo_path, SponserID))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sponsor not found")

            con.commit()

        return {
            "msg": "Sponsor updated successfully",
            "Sponser_ID": SponserID,
            "SponserLogoPath": logo_path,
        }

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


#----------------------------------------------------------------------------------------------------------------------


async def get_all_Sponsers():
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("""
                SELECT * FROM sponserinfo
            """)
            sponserinfo = cur.fetchall()

        return {"sponserinfo": sponserinfo}

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_sponser_by_id(sponser_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("""
                SELECT *
                FROM sponserinfo
                WHERE SponserID = %s
            """, (sponser_id,))
            sponserinfo = cur.fetchone()

        if sponserinfo is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="eventimageinfo not found")

        return {"sponserinfo": sponserinfo}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def update_Sponser(req_data: UpdateSponserInfoRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                UPDATE sponserinfo
                SET SponserName = %s,
                    SponserLogoPath = %s
                WHERE SponserID = %s
            """
            cur.execute(sql, (
                req_data.SponserName,
                req_data.SponserLogoPath,
                req_data.SponserID
            ))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

            con.commit()

        return {"msg": "Event updated successfully", "Sponser_ID": req_data.SponserID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def delete_Sponser(Sponser_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("DELETE FROM sponserinfo WHERE SponserID = %s", (Sponser_id,))
            rows_deleted = cur.rowcount
            con.commit()

        if rows_deleted == 0:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        return {"msg": "Event deleted successfully", "Sponser_id": Sponser_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})

    #----------------------------------------------------------------------------------------------------------------------

async def create_EventSponser(req_data: AddEventSponserInfoRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                INSERT INTO eventsponserinfo
                (EventID,SponserID)
                VALUES (%s, %s)
            """
            cur.execute(sql, (
                req_data.EventID,
                req_data.SponserID
            ))
            con.commit()
            EventSponser_ID = cur.lastrowid

        return {"msg": "Event created successfully", "EventSponser_ID": EventSponser_ID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_all_EventSponsers():
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("""
                SELECT * FROM eventsponserinfo
            """)
            eventsponserinfo = cur.fetchall()

        return {"eventsponserinfo": eventsponserinfo}

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_EventSponser_by_id(eventsponser_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("""
                SELECT *
                FROM eventsponserinfo
                WHERE EventSponserID = %s
            """, (eventsponser_id,))
            eventsponserinfo = cur.fetchone()

        if eventsponserinfo is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="eventimageinfo not found")

        return {"eventsponserinfo": eventsponserinfo}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def update_EventSponser(req_data: UpdateEventSponserInfoRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                UPDATE eventsponserinfo
                SET EventID = %s,
                    SponserID = %s
                WHERE EventSponserID = %s
            """
            cur.execute(sql, (
                req_data.EventID,
                req_data.SponserID,
                req_data.EventSponserID
            ))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

            con.commit()

        return {"msg": "Event updated successfully", "EventSponserID": req_data.EventSponserID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def delete_EventSponser(EventSponser_ID: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("DELETE FROM eventsponserinfo WHERE EventSponserID = %s", (EventSponser_ID,))
            rows_deleted = cur.rowcount
            con.commit()

        if rows_deleted == 0:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        return {"msg": "Event deleted successfully", "EventSponser_ID": EventSponser_ID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})
