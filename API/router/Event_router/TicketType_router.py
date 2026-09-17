from fastapi import APIRouter
from controllers.Event_Controllers.TicketType_Controller import (
    create_TicketType, get_all_TicketType, get_TicketType_by_id, get_TicketType_by_EventID, get_TicketType_by_Anything, update_TicketType, delete_TicketType
)
from models.schema import AddTicketTypeRequest, UpdateTicketTypeRequest

router = APIRouter(prefix="/tickettype", tags=["TicketType"])

router.post("/create")(create_TicketType)
router.get("/all")(get_all_TicketType)
router.get("/{tickettype_id}")(get_TicketType_by_id)
router.get("/event/{event_id}")(get_TicketType_by_EventID)
router.get("/search/{value}")(get_TicketType_by_Anything)
router.put("/update")(update_TicketType)
router.delete("/{tickettype_id}")(delete_TicketType)