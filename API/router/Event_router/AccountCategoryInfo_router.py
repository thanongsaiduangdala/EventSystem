from fastapi import APIRouter
from controllers.Event_Controllers.AccountCategoryInfo_controllers import (
    set_account_categories, add_account_category, get_all_account_categories,
    get_account_categories, delete_account_category, get_recommended_events_for_account
)

router = APIRouter(prefix="/accountcategory", tags=["AccountCategory"])

router.post("/set")(set_account_categories)
router.post("/add")(add_account_category)
router.get("/all")(get_all_account_categories)
router.get("/recommended/{account_id}")(get_recommended_events_for_account)
router.get("/{account_id}")(get_account_categories)
router.delete("/{account_category_id}")(delete_account_category)
