from fastapi import APIRouter
from controllers.Event_Controllers.TeamRole_controllers import (
    create_teamrole, get_all_TeamRoles, get_teamrole_by_id, update_teamrole, delete_teamrole
)

router = APIRouter(prefix="/teamrole", tags=["TeamRole"])

# teamrole
router.post("/role/create")(create_teamrole)
router.get("/role/all")(get_all_TeamRoles)
router.get("/role/{team_role_id}")(get_teamrole_by_id)
router.put("/role/update")(update_teamrole)
router.delete("/role/{team_role_id}")(delete_teamrole)

