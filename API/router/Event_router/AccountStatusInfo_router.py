from fastapi import APIRouter

from controllers.Event_Controllers.AccountStatusInfo_controllers import (
    create_accountstatusinfo, get_all_accountstatusinfo, get_accountstatusinfo_by_id,
    update_accountstatusinfo, delete_accountstatus
)

router = APIRouter(prefix="/accountstatus", tags=["Account status"])

router.post("/create")(create_accountstatusinfo)
router.get("/all")(get_all_accountstatusinfo)
router.get("/{status_id}")(get_accountstatusinfo_by_id)
router.put("/update")(update_accountstatusinfo)
router.delete("/{status_id}")(delete_accountstatus)