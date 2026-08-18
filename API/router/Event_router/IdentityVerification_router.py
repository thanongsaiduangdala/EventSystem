from fastapi import APIRouter
from controllers.Event_Controllers.IdentityVerification_controllers import (
    create_identityverification, get_all_identityverifications, get_identityverification_by_id,
    get_identityverifications_by_account_id, update_identityverification, delete_identityverification,
    get_verified_accounts_for_organizer
)
from controllers.Event_Controllers.VerificationTypeInfo_controllers import (
    create_Verificationtype, get_all_VerificationTypes, get_Verificationtype_by_id,
    update_Verificationtype, delete_Verificationtype
)
from controllers.Event_Controllers.VerificationStatusInfo_controllers import (
    create_Verificationstatus, get_all_VerificationStatuses, get_Verificationstatus_by_id,
    update_Verificationstatus, delete_Verificationstatus
)

router = APIRouter(prefix="/identityverification", tags=["identityverification"])

# identityverification
router.post("/verification/create")(create_identityverification)
router.get("/verification/all")(get_all_identityverifications)
# IMPORTANT: this static route must come before "/verification/{Verification_id}"
# below, otherwise FastAPI matches it as that dynamic route first and 422s
# trying to parse "verified-accounts" as an int.
router.get("/verification/verified-accounts")(get_verified_accounts_for_organizer)
router.get("/verification/{Verification_id}")(get_identityverification_by_id)
router.get("/verification/by-account/{account_id}")(get_identityverifications_by_account_id)
router.put("/verification/update")(update_identityverification)
router.delete("/verification/{Verification_id}")(delete_identityverification)

# Verificationtypeinfo
router.post("/type/create")(create_Verificationtype)
router.get("/type/all")(get_all_VerificationTypes)
router.get("/type/{Verification_type_id}")(get_Verificationtype_by_id)
router.put("/type/update")(update_Verificationtype)
router.delete("/type/{Verification_type_id}")(delete_Verificationtype)

# Verificationstatusinfo
router.post("/status/create")(create_Verificationstatus)
router.get("/status/all")(get_all_VerificationStatuses)
router.get("/status/{Verification_status_id}")(get_Verificationstatus_by_id)
router.put("/status/update")(update_Verificationstatus)
router.delete("/status/{Verification_status_id}")(delete_Verificationstatus)