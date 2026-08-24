from fastapi import APIRouter
from controllers.Event_Controllers.Wishlist_controllers import (
    create_wish, get_all_wishlist, get_wishlist_by_account, check_wish,
    delete_wish, delete_wish_by_id
)

router = APIRouter(prefix="/wishlist", tags=["Wishlist"])

router.post("/create")(create_wish)
router.get("/all")(get_all_wishlist)
router.get("/account/{account_id}")(get_wishlist_by_account)
router.get("/check/{account_id}/{event_id}")(check_wish)
router.delete("/{account_id}/{event_id}")(delete_wish)
router.delete("/id/{wish_id}")(delete_wish_by_id)
