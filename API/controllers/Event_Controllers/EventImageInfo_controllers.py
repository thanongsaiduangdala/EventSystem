import io
import os
import uuid
from pathlib import Path
from typing import Optional

import pymysql
from fastapi import HTTPException, UploadFile, status
from PIL import Image, UnidentifiedImageError
from DB.DBConnect import getConnect
from models.schema import AddEventImageInfoRequest, UpdateEventImageInfoRequest

# ---------------------------------------------------------------------------
# File storage config
#
# Assumes the app is launched from the project root (e.g. `uvicorn main:app`
# run from the folder containing main.py). If your working directory differs,
# change BASE_DIR to an absolute path instead.
# ---------------------------------------------------------------------------
BASE_DIR = Path(os.getcwd())
STATIC_DIR = BASE_DIR / "static" / "event_images"

# Requires a new column on eventimageinfo (run once):
#   ALTER TABLE eventimageinfo ADD COLUMN IsThumbnail TINYINT(1) NOT NULL DEFAULT 0;
# At most one row per EventID should have IsThumbnail = 1 -- enforced in code
# by set_thumbnail_eventimage() below, not by a DB constraint.

ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".gif"}
MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024  # 5 MB
THUMBNAIL_MAX_SIZE = (300, 300)  # fits within this box, aspect ratio preserved


def _thumb_name_for(filename: str) -> str:
    """abc123.jpg -> abc123_thumb.jpg. Deterministic so no DB column is needed --
    the thumbnail's URL is always derivable from ImagePath."""
    stem, ext = os.path.splitext(filename)
    return f"{stem}_thumb{ext}"


def _write_thumbnail(contents: bytes, dest_path: Path) -> None:
    """Best-effort thumbnail generation. Never raises -- a failed thumbnail
    should not block the main upload from succeeding."""
    try:
        with Image.open(io.BytesIO(contents)) as img:
            # JPEG has no alpha channel; flatten RGBA/P images before saving as .jpg
            if dest_path.suffix.lower() in (".jpg", ".jpeg") and img.mode in ("RGBA", "P", "LA"):
                img = img.convert("RGB")
            img.thumbnail(THUMBNAIL_MAX_SIZE, Image.LANCZOS)
            img.save(dest_path, quality=85)
    except (UnidentifiedImageError, OSError, ValueError):
        pass


async def _save_image_file(event_id: int, file: UploadFile) -> str:
    """Validates + writes an uploaded file (and its thumbnail) to disk,
    returns the URL path to store in the DB."""
    ext = Path(file.filename or "").suffix.lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported file type '{ext}'. Allowed: {sorted(ALLOWED_EXTENSIONS)}",
        )

    contents = await file.read()
    if len(contents) > MAX_FILE_SIZE_BYTES:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="File too large (max 5MB)")
    if len(contents) == 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Empty file")

    event_dir = STATIC_DIR / str(event_id)
    event_dir.mkdir(parents=True, exist_ok=True)

    unique_name = f"{uuid.uuid4().hex}{ext}"
    dest_path = event_dir / unique_name

    with open(dest_path, "wb") as f:
        f.write(contents)

    _write_thumbnail(contents, event_dir / _thumb_name_for(unique_name))

    # This is the path stored in the DB and served over HTTP -- NOT the disk path.
    return f"/static/event_images/{event_id}/{unique_name}"


def _delete_image_file(image_path: Optional[str]) -> None:
    """Best-effort removal of the file (and its thumbnail) backing an ImagePath. Never raises."""
    if not image_path or not image_path.startswith("/static/"):
        return
    file_path = BASE_DIR / image_path.lstrip("/")
    thumb_path = file_path.with_name(_thumb_name_for(file_path.name))
    for p in (file_path, thumb_path):
        try:
            if p.exists():
                p.unlink()
        except OSError:
            pass


async def create_eventimage(req_data: AddEventImageInfoRequest):
    """Kept for compatibility (e.g. re-pointing an image at an already-hosted URL).
    For actual file uploads use upload_eventimage instead."""
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                INSERT INTO eventimageinfo
                (EventID,ImageName,ImagePath)
                VALUES (%s, %s, %s)
            """
            cur.execute(sql, (
                req_data.EventID,
                req_data.ImageName,
                req_data.ImagePath,
            ))
            con.commit()
            Image_ID = cur.lastrowid

        return {"msg": "Event created successfully", "Image_ID": Image_ID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def upload_eventimage(event_id: int, file: UploadFile, image_name: Optional[str] = None):
    """Saves an uploaded file to disk under static/event_images/{event_id}/ and
    creates the eventimageinfo row pointing at it."""
    try:
        relative_path = await _save_image_file(event_id, file)
        display_name = image_name or file.filename or "image"

        con = getConnect()
        with con.cursor() as cur:
            sql = """
                INSERT INTO eventimageinfo
                (EventID,ImageName,ImagePath)
                VALUES (%s, %s, %s)
            """
            cur.execute(sql, (event_id, display_name, relative_path))
            con.commit()
            Image_ID = cur.lastrowid

        return {
            "msg": "Event image uploaded successfully",
            "Image_ID": Image_ID,
            "ImagePath": relative_path,
        }

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def replace_eventimage_file(image_id: int, file: UploadFile, image_name: Optional[str] = None):
    """Uploads a new file for an existing eventimageinfo row, swaps ImagePath
    to point at it, and deletes the old file from disk."""
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("SELECT EventID, ImagePath FROM eventimageinfo WHERE ImageID = %s", (image_id,))
            row = cur.fetchone()
            if row is None:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="eventimageinfo not found")

            event_id = row["EventID"] if isinstance(row, dict) else row[0]
            old_path = row["ImagePath"] if isinstance(row, dict) else row[1]

            new_path = await _save_image_file(event_id, file)

            if image_name:
                cur.execute(
                    "UPDATE eventimageinfo SET ImageName = %s, ImagePath = %s WHERE ImageID = %s",
                    (image_name, new_path, image_id),
                )
            else:
                cur.execute(
                    "UPDATE eventimageinfo SET ImagePath = %s WHERE ImageID = %s",
                    (new_path, image_id),
                )
            con.commit()

        _delete_image_file(old_path)

        return {
            "msg": "Event image replaced successfully",
            "ImageID": image_id,
            "ImagePath": new_path,
        }

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def set_thumbnail_eventimage(image_id: int):
    """Marks this image as THE thumbnail for its event, and unmarks whichever
    other image (if any) previously held that spot for the same EventID.
    Only one row per EventID can have IsThumbnail = 1 at a time."""
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("SELECT EventID FROM eventimageinfo WHERE ImageID = %s", (image_id,))
            row = cur.fetchone()
            if row is None:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="eventimageinfo not found")
            event_id = row["EventID"] if isinstance(row, dict) else row[0]

            # Clear the old thumbnail for this event first, then set the new one --
            # keeps it to a single UPDATE pass per direction and avoids a moment
            # where two rows are both flagged if something in between fails.
            cur.execute(
                "UPDATE eventimageinfo SET IsThumbnail = 0 WHERE EventID = %s AND ImageID != %s",
                (event_id, image_id),
            )
            cur.execute(
                "UPDATE eventimageinfo SET IsThumbnail = 1 WHERE ImageID = %s",
                (image_id,),
            )
            con.commit()

        return {"msg": "Thumbnail updated successfully", "ImageID": image_id, "EventID": event_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_all_eventimages():
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("""
                SELECT * FROM eventimageinfo
            """)
            eventimageinfo = cur.fetchall()

        return {"eventimageinfo": eventimageinfo}

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_eventimage_by_id(image_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("""
                SELECT *
                FROM eventimageinfo
                WHERE ImageID = %s
            """, (image_id,))
            eventimageinfo = cur.fetchone()

        if eventimageinfo is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="eventimageinfo not found")

        return {"eventimageinfo": eventimageinfo}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def update_eventimage(req_data: UpdateEventImageInfoRequest):
    """Renames / re-points a record without touching the file (use replace_eventimage_file
    to actually swap the underlying image)."""
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                UPDATE eventimageinfo
                SET EventID = %s,
                    ImageName = %s,
                    ImagePath = %s
                WHERE ImageID = %s
            """
            cur.execute(sql, (
                req_data.EventID,
                req_data.ImageName,
                req_data.ImagePath,
                req_data.ImageID,
            ))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

            con.commit()

        return {"msg": "Event updated successfully", "ImageID": req_data.ImageID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def delete_eventimage(image_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("SELECT ImagePath FROM eventimageinfo WHERE ImageID = %s", (image_id,))
            row = cur.fetchone()

            cur.execute("DELETE FROM eventimageinfo WHERE ImageID = %s", (image_id,))
            rows_deleted = cur.rowcount
            con.commit()

        if rows_deleted == 0:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        if row:
            old_path = row["ImagePath"] if isinstance(row, dict) else row[0]
            _delete_image_file(old_path)

        return {"msg": "Event deleted successfully", "image_id": image_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})