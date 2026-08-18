from fastapi import APIRouter
from controllers.Event_Controllers.EventStaff_controllers import (
    create_eventstaff, get_all_EventStaff, get_eventstaff_by_id,
    get_eventstaff_by_event_id, update_eventstaff, delete_eventstaff
)
from controllers.Event_Controllers.EventRole_controllers import (
    create_eventrole, get_all_EventRoles, get_eventrole_by_id,
    update_eventrole, delete_eventrole
)

router = APIRouter(prefix="/eventstaff", tags=["EventStaff"])

# eventstaff
router.post("/staff/create")(create_eventstaff)
router.get("/staff/all")(get_all_EventStaff)
router.get("/staff/{assignment_id}")(get_eventstaff_by_id)
router.get("/staff/by-event/{event_id}")(get_eventstaff_by_event_id)
router.put("/staff/update")(update_eventstaff)
router.delete("/staff/{assignment_id}")(delete_eventstaff)

# eventRole
router.post("/role/create")(create_eventrole)
router.get("/role/all")(get_all_EventRoles)
router.get("/role/{event_role_id}")(get_eventrole_by_id)
router.put("/role/update")(update_eventrole)
router.delete("/role/{event_role_id}")(delete_eventrole)
