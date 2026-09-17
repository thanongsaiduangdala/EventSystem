from fastapi import APIRouter, status
from models.schema import (
    SignUpRequest, LoginRequest, SendOtpRequest,
    ResetPasswordRequest, SignupOtpRequest, VerifyOtpRequest,
)
from controllers import auth_controller

router = APIRouter()

router.add_api_route("/signup", auth_controller.signup, methods=["POST"], status_code=status.HTTP_201_CREATED)
router.add_api_route("/login", auth_controller.login, methods=["POST"], status_code=status.HTTP_200_OK)
router.add_api_route("/forgot-password/send-otp", auth_controller.send_forgot_otp, methods=["POST"], status_code=status.HTTP_200_OK)
router.add_api_route("/forgot-password/reset", auth_controller.reset_password, methods=["POST"], status_code=status.HTTP_200_OK)
router.add_api_route("/forgot-password/verify-otp", auth_controller.verify_otp, methods=["POST"], status_code=status.HTTP_200_OK)
router.add_api_route("/signup/send-otp", auth_controller.send_signup_otp, methods=["POST"], status_code=status.HTTP_200_OK)
router.add_api_route("/account/{account_id}/status", auth_controller.get_account_status, methods=["GET"], status_code=status.HTTP_200_OK)
router.add_api_route("/account/status", auth_controller.check_developer_status, methods=["GET"], status_code=status.HTTP_200_OK)