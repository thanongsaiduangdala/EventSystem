from fastapi import APIRouter
from controllers.Event_Controllers.Notification_controllers import (
    create_notification,
    generate_for_account,
    get_notifications_by_account,
    get_unread_count,
    mark_notification_read,
    mark_all_read,
    stream_notifications,
)

router = APIRouter(prefix="/notification", tags=["Notification"])

router.post("/create")(create_notification)
router.post("/generate/{account_id}")(generate_for_account)
router.get("/stream")(stream_notifications)
router.get("/account/{account_id}")(get_notifications_by_account)
router.get("/unread/{account_id}")(get_unread_count)
router.put("/read/{notification_id}")(mark_notification_read)
router.put("/read-all/{account_id}")(mark_all_read)