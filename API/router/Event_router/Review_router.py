from fastapi import APIRouter
from controllers.Event_Controllers.Review_controllers import review_socket

router = APIRouter(prefix="/review", tags=["Review"])

router.websocket("/ws")(review_socket)
