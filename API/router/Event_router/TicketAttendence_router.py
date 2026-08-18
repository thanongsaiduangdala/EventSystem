from fastapi import APIRouter
from controllers.Event_Controllers.TicketAttendence_controllers import (
    create_ticketattendee, get_all_TicketAttendees, get_ticketattendee_by_id,
    get_ticketattendees_by_order_id, update_ticketattendee, delete_ticketattendee
)

router = APIRouter(prefix="/ticketattendence", tags=["TicketAttendence"])

router.post("/attendee/create")(create_ticketattendee)
router.get("/attendee/all")(get_all_TicketAttendees)
router.get("/attendee/{attendee_id}")(get_ticketattendee_by_id)
router.get("/attendee/by-order/{order_id}")(get_ticketattendees_by_order_id)
router.put("/attendee/update")(update_ticketattendee)
router.delete("/attendee/{attendee_id}")(delete_ticketattendee)
