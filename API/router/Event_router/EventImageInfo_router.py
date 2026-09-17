from typing import Optional

from fastapi import APIRouter, File, Form, UploadFile
from controllers.Event_Controllers.EventImageInfo_controllers import (
    create_eventimage,
    get_all_eventimages,
    get_eventimage_by_id,
    update_eventimage,
    delete_eventimage,
    upload_eventimage,
    replace_eventimage_file,
    set_thumbnail_eventimage,
)

router = APIRouter(prefix="/eventimage", tags=["EventImage"])

router.post("/create")(create_eventimage)
router.get("/all")(get_all_eventimages)
router.get("/{image_id}")(get_eventimage_by_id)
router.put("/update")(update_eventimage)
router.delete("/{image_id}")(delete_eventimage)


@router.post("/upload")
async def upload_eventimage_route(
    event_id: int = Form(...),
    image_name: Optional[str] = Form(None),
    file: UploadFile = File(...),
):
    """Multipart upload: saves the file to disk and creates the DB row in one step."""
    return await upload_eventimage(event_id=event_id, file=file, image_name=image_name)


@router.post("/{image_id}/replace")
async def replace_eventimage_route(
    image_id: int,
    image_name: Optional[str] = Form(None),
    file: UploadFile = File(...),
):
    """Multipart upload: swaps the file backing an existing image row and deletes the old one."""
    return await replace_eventimage_file(image_id=image_id, file=file, image_name=image_name)


router.post("/{image_id}/set-thumbnail")(set_thumbnail_eventimage)


# ---------------------------------------------------------------------------
# One-time setup needed in main.py so uploaded files are actually servable:
#
#   from fastapi.staticfiles import StaticFiles
#   app.mount("/static", StaticFiles(directory="static"), name="static")
#
# This must run from the same working directory the controller writes to
# (BASE_DIR = os.getcwd() in EventImageInfo_controllers.py).
# ---------------------------------------------------------------------------