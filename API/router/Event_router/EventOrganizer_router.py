from fastapi import APIRouter
from controllers.Event_Controllers.EventOrganizerInfo_controllers import (
    create_eventorganizer, get_all_EventOrganizers, get_eventorganizer_by_id,
    update_eventorganizer, delete_eventorganizer,
    upload_eventorganizer, replace_eventorganizer_logo, apply_eventorganizer,
    approve_eventorganizer, deny_eventorganizer
)
from controllers.Event_Controllers.OrganizerMember_controllers import (
    create_organizermember, get_all_OrganizerMembers, get_organizermember_by_id,
    update_organizermember, delete_organizermember,
    invite_organizermember, accept_organizermember, decline_organizermember,
    get_organizermembers_with_accounts,
    get_my_memberships, get_my_invites, get_my_team_member_events, get_org_team,
    change_member_role, transfer_org_ownership,
    assign_member_to_event, unassign_member_from_event,
    get_event_scan_access, set_event_scan_enabled, set_member_scan_access
)

router = APIRouter(prefix="/eventorganizer", tags=["EventOrganizer"])

router.post("/organizer/create")(create_eventorganizer)
router.post("/organizer/upload")(upload_eventorganizer)
router.post("/organizer/apply")(apply_eventorganizer)
router.put("/organizer/replace")(replace_eventorganizer_logo)
router.post("/organizer/{event_organizer_id}/approve")(approve_eventorganizer)
router.post("/organizer/{event_organizer_id}/deny")(deny_eventorganizer)
router.get("/organizer/all")(get_all_EventOrganizers)
router.get("/organizer/{event_organizer_id}")(get_eventorganizer_by_id)
router.put("/organizer/update")(update_eventorganizer)
router.delete("/organizer/{event_organizer_id}")(delete_eventorganizer)

router.post("/member/create")(create_organizermember)
router.post("/member/invite")(invite_organizermember)
router.get("/member/all")(get_all_OrganizerMembers)
router.get("/member/all-with-accounts")(get_organizermembers_with_accounts)
router.get("/member/my-memberships")(get_my_memberships)
router.get("/member/my-invites")(get_my_invites)
router.get("/member/member-events")(get_my_team_member_events)
router.get("/member/team/{org_id}")(get_org_team)
router.put("/member/change-role")(change_member_role)
router.post("/member/transfer-ownership")(transfer_org_ownership)
router.post("/member/assign-event")(assign_member_to_event)
router.post("/member/unassign-event")(unassign_member_from_event)
router.get("/member/event-scan/{event_id}")(get_event_scan_access)
router.post("/member/event-scan/enabled")(set_event_scan_enabled)
router.post("/member/event-scan/member")(set_member_scan_access)
router.post("/member/{member_id}/accept")(accept_organizermember)
router.post("/member/{member_id}/decline")(decline_organizermember)
router.get("/member/{member_id}")(get_organizermember_by_id)
router.put("/member/update")(update_organizermember)
router.delete("/member/{member_id}")(delete_organizermember)
