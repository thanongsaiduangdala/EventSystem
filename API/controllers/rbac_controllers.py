import pymysql
from fastapi import HTTPException, status, Depends
from DB.DBConnect import getConnect
from auth.dependencies import (
    require_superadmin, get_current_account, get_account_role_and_permissions,
    get_permissions_for_status, role_name,
)
from models.schema import AssignRolePermissionRequest

ROLE_IDS = [1, 2, 3]


async def get_all_permissions(current=Depends(require_superadmin)):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("SELECT * FROM permissioninfo ORDER BY PermissionName")
            rows = cur.fetchall()
        return {"permissions": rows}
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_role_permissions(status_id: int, current=Depends(require_superadmin)):
    if status_id not in ROLE_IDS:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Unknown role")
    try:
        con = getConnect()
        permissions = get_permissions_for_status(con, status_id)
        return {
            "RoleID": status_id,
            "RoleName": role_name(status_id),
            "Permissions": permissions,
        }
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_me(current=Depends(get_current_account)):
    """Returns the logged-in account's user id, role and permissions."""
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute(
                "SELECT AccountID, StatusID FROM accountinfo WHERE AccountID = %s",
                (current["account_id"],),
            )
            row = cur.fetchone()
        if row is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Account not found")

        role_info = get_account_role_and_permissions(con, row["AccountID"])
        return {
            "AccountID": row["AccountID"],
            "StatusID": row["StatusID"],
            "Role": role_info["Role"],
            "Permissions": role_info["Permissions"],
        }
    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def assign_permission_to_role(req: AssignRolePermissionRequest, current=Depends(require_superadmin)):
    if req.status_id not in ROLE_IDS:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Unknown role")
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute(
                "INSERT IGNORE INTO rolepermissioninfo (StatusID, PermissionID) VALUES (%s, %s)",
                (req.status_id, req.permission_id),
            )
            con.commit()
        return {"msg": "Permission assigned" if cur.rowcount > 0 else "Permission already assigned"}
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def revoke_permission_from_role(req: AssignRolePermissionRequest, current=Depends(require_superadmin)):
    if req.status_id not in ROLE_IDS:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Unknown role")
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute(
                "DELETE FROM rolepermissioninfo WHERE StatusID = %s AND PermissionID = %s",
                (req.status_id, req.permission_id),
            )
            if cur.rowcount == 0:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Role permission not found")
            con.commit()
        return {"msg": "Permission revoked"}
    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})