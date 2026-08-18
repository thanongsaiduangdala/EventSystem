from fastapi import APIRouter
from controllers.Event_Controllers.CategoryInfo_controllers import (
    create_category, get_all_Categories, get_category_by_id, update_category, delete_category
)
from controllers.Event_Controllers.EventCategoryInfo_controllers import (
    create_eventcategory, get_all_EventCategories, get_eventcategory_by_id,
    get_categories_by_event_id, update_eventcategory, delete_eventcategory
)

router = APIRouter(prefix="/eventcategory", tags=["EventCategory"])

# categoryinfo
router.post("/category/create")(create_category)
router.get("/category/all")(get_all_Categories)
router.get("/category/{category_id}")(get_category_by_id)
router.put("/category/update")(update_category)
router.delete("/category/{category_id}")(delete_category)

# eventcategoryinfo (link table)
router.post("/event/create")(create_eventcategory)
router.get("/event/all")(get_all_EventCategories)
router.get("/event/{event_category_id}")(get_eventcategory_by_id)
router.get("/event/by-event/{event_id}")(get_categories_by_event_id)
router.put("/event/update")(update_eventcategory)
router.delete("/event/{event_category_id}")(delete_eventcategory)
