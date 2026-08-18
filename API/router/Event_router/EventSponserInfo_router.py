from fastapi import APIRouter
from controllers.Event_Controllers.EventSponserInfo_controllers import (
    create_sponser, get_all_Sponsers, get_sponser_by_id, update_Sponser, delete_Sponser,
    upload_sponser, replace_sponser_logo,
    create_EventSponser, get_all_EventSponsers, get_EventSponser_by_id, update_EventSponser, delete_EventSponser
)

router = APIRouter(prefix="/eventsponser", tags=["Eventsponser"])

router.post("/sponser/createsponser")(create_sponser)
router.get("/sponser/all")(get_all_Sponsers)
router.get("/sponser/{sponser_id}")(get_sponser_by_id)
router.put("/sponser/update")(update_Sponser)
router.delete("/sponser/{Sponser_id}")(delete_Sponser)

# NEW: multipart file-upload endpoints, used by thes sponsor logo picker.
router.post("/sponser/upload")(upload_sponser)
router.put("/sponser/replace")(replace_sponser_logo)

#-----------------------------------------------------

router.post("/eventsponser/createsponser")(create_EventSponser)
router.get("/eventsponser/all")(get_all_EventSponsers)
router.get("/eventsponser/{eventsponser_id}")(get_EventSponser_by_id)
router.put("/eventsponser/update")(update_EventSponser)
router.delete("/eventsponser/{EventSponser_ID}")(delete_EventSponser)
