from fastapi import APIRouter

from controllers.Event_Controllers.AttendeeResponse_controllers import (
    create_attendeeresponse, get_all_AttendeeResponses, get_attendeeresponse_by_id,
    get_attendeeresponses_by_attendee_id, update_attendeeresponse, delete_attendeeresponse
)

router = APIRouter(prefix="/response", tags=["Attendee Response"])

router.post("/create")(create_attendeeresponse)
router.get("/all")(get_all_AttendeeResponses)
router.get("/{response_id}")(get_attendeeresponse_by_id)
router.get("/by-attendee/{attendee_id}")(get_attendeeresponses_by_attendee_id)
router.put("/update")(update_attendeeresponse)
router.delete("/{response_id}")(delete_attendeeresponse)