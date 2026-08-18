from fastapi import APIRouter
from controllers.Account_Controllers.Account_controllers import (
    create_account, get_all_accounts, get_account_by_id, update_account, delete_account
)
from models.schema import AddEventInfoRequest, UpdateEventInfoRequest

router = APIRouter(prefix="/Account", tags=["Account"])

router.post("/create")(create_account)
router.get("/all")(get_all_accounts)
router.get("/{event_id}")(get_account_by_id)
router.put("/update")(update_account)
router.delete("/{event_id}")(delete_account)