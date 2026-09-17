from fastapi import APIRouter
from controllers.rbac_controllers import (
    get_all_permissions, get_role_permissions, get_me,
    assign_permission_to_role, revoke_permission_from_role,
)

router = APIRouter(prefix="/rbac", tags=["RBAC"])

router.get("/permissions/all")(get_all_permissions)
router.get("/role/{status_id}/permissions")(get_role_permissions)
router.get("/me")(get_me)
router.post("/role/permission/assign")(assign_permission_to_role)
router.post("/role/permission/revoke")(revoke_permission_from_role)