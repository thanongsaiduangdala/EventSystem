from fastapi import APIRouter
from controllers.Event_Controllers.Event_Controllers import (
    create_event, get_all_events, get_events_with_status, get_event_by_id,
    update_event, update_event_status, delete_event
)
from models.schema import AddEventInfoRequest, UpdateEventInfoRequest, UpdateEventStatusRequest

router = APIRouter(prefix="/event", tags=["Event"])

router.post("/create")(create_event)
router.get("/all")(get_all_events)
router.get("/all-with-status")(get_events_with_status)
router.get("/{event_id}")(get_event_by_id)
router.put("/update")(update_event)
router.put("/status")(update_event_status)
router.delete("/{event_id}")(delete_event)