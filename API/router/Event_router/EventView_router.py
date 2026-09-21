from fastapi import APIRouter
from controllers.Event_Controllers.EventView_controllers import (
    create_event_view, get_all_event_views, get_event_views_by_account
)

router = APIRouter(prefix="/eventview", tags=["EventView"])

router.post("/create")(create_event_view)
router.get("/all")(get_all_event_views)
router.get("/account/{account_id}")(get_event_views_by_account)