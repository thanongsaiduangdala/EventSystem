from fastapi import APIRouter
from controllers.Event_Controllers.Follow_controllers import (
    create_follow, get_all_follows, get_follows_by_account, get_followed_events,
    check_follow, delete_follow
)

router = APIRouter(prefix="/follow", tags=["Follow"])

router.post("/create")(create_follow)
router.get("/all")(get_all_follows)
router.get("/account/{account_id}")(get_follows_by_account)
router.get("/events/{account_id}")(get_followed_events)
router.get("/check/{account_id}/{organizer_id}")(check_follow)
router.delete("/{account_id}/{organizer_id}")(delete_follow)