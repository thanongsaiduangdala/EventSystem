from fastapi import APIRouter
from controllers.Event_Controllers.OrganizerMember_controllers import (
    create_organizermember, get_all_OrganizerMembers, get_organizermember_by_id,
    update_organizermember, delete_organizermember,
    invite_organizermember, accept_organizermember, decline_organizermember,
    get_organizermembers_with_accounts
)

router = APIRouter(prefix="/organizermember", tags=["OrganizerMember"])

router.post("/create")(create_organizermember)
router.post("/invite")(invite_organizermember)
router.get("/all")(get_all_OrganizerMembers)
router.get("/all-with-accounts")(get_organizermembers_with_accounts)
router.post("/{member_id}/accept")(accept_organizermember)
router.post("/{member_id}/decline")(decline_organizermember)
router.get("/{member_id}")(get_organizermember_by_id)
router.put("/update")(update_organizermember)
router.delete("/{member_id}")(delete_organizermember)