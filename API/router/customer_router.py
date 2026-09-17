from fastapi import APIRouter, status
from controllers import customer_controller

router = APIRouter()

router.add_api_route("/customer/delete", customer_controller.delete_customer, methods=["DELETE"], status_code=status.HTTP_200_OK)
router.add_api_route("/signup/check-duplicate", customer_controller.check_duplicate, methods=["POST"], status_code=status.HTTP_200_OK)