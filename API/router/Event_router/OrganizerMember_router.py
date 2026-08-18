from fastapi import APIRouter
from controllers.Event_Controllers.OrganizerMember_controllers import (
    create_organizermember, get_all_OrganizerMembers, get_organizermember_by_id,
    update_organizermember, delete_organizermember
)

router = APIRouter(prefix="/organizermember", tags=["OrganizerMember"])

router.post("/create")(create_organizermember)
router.get("/all")(get_all_OrganizerMembers)
router.get("/{member_id}")(get_organizermember_by_id)
router.put("/update")(update_organizermember)
router.delete("/{member_id}")(delete_organizermember)
