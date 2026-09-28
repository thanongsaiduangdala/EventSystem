from fastapi import APIRouter
from controllers.Event_Controllers.EventQuestion_Controllers import (
    create_event,
    get_all_events,
    get_event_by_id,
    get_eventquestions_by_event_id,
    update_event,
    delete_event,
    create_eventquestiontype,
    get_all_eventquestiontypes,
    get_eventquestiontype_by_id,
    update_eventquestiontype,
    delete_eventquestiontype,
)

router = APIRouter(prefix="/eventquestion", tags=["EventQuestion"])


# ---------------- eventquestioninfo ----------------

router.post("/")(create_event)

router.get("/")(get_all_events)

router.put("/")(update_event)


# ---------------- eventquestiontype ----------------

router.post("/type")(create_eventquestiontype)

router.get("/type")(get_all_eventquestiontypes)

router.get("/type/{eventquestiontype_id}")(get_eventquestiontype_by_id)

router.put("/type")(update_eventquestiontype)

router.delete("/type/{eventquestiontype_id}")(delete_eventquestiontype)


# ---------------- eventquestion read by event / id ----------------

router.get("/event/{event_id}")(get_eventquestions_by_event_id)

router.get("/{eventquestion_id}")(get_event_by_id)

router.delete("/{eventquestion_id}")(delete_event)