from fastapi import APIRouter
from controllers.Event_Controllers.EventOrganizerInfo_controllers import (
    create_eventorganizer, get_all_EventOrganizers, get_eventorganizer_by_id,
    update_eventorganizer, delete_eventorganizer,
    upload_eventorganizer, replace_eventorganizer_logo
)
from controllers.Event_Controllers.OrganizerMember_controllers import (
    create_organizermember, get_all_OrganizerMembers, get_organizermember_by_id,
    update_organizermember, delete_organizermember
)

router = APIRouter(prefix="/eventorganizer", tags=["EventOrganizer"])

# eventorganizerInfo
router.post("/organizer/create")(create_eventorganizer)
router.post("/organizer/upload")(upload_eventorganizer)
router.put("/organizer/replace")(replace_eventorganizer_logo)
router.get("/organizer/all")(get_all_EventOrganizers)
router.get("/organizer/{event_organizer_id}")(get_eventorganizer_by_id)
router.put("/organizer/update")(update_eventorganizer)
router.delete("/organizer/{event_organizer_id}")(delete_eventorganizer)

# organizermember
router.post("/member/create")(create_organizermember)
router.get("/member/all")(get_all_OrganizerMembers)
router.get("/member/{member_id}")(get_organizermember_by_id)
router.put("/member/update")(update_organizermember)
router.delete("/member/{member_id}")(delete_organizermember)
