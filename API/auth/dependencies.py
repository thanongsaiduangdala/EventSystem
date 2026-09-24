from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError
from auth.jwt_handler import decode_access_token
from DB.DBConnect import getConnect

bearer_scheme = HTTPBearer()

# Role IDs come from accountstatusinfo.StatusID.
ROLE_CUSTOMER = 1
ROLE_ORGANIZER = 2
ROLE_SUPERADMIN = 3
ROLE_EMPLOYEE = 4

ROLE_NAMES = {
    ROLE_CUSTOMER: "CUSTOMER",
    ROLE_ORGANIZER: "ORGANIZER",
    ROLE_SUPERADMIN: "SUPERADMIN",
    ROLE_EMPLOYEE: "EMPLOYEE",
}


def role_name(status_id):
    """Returns the canonical role name for a status id, or None if unknown."""
    return ROLE_NAMES.get(status_id)


def get_permissions_for_status(con, status_id) -> list:
    """Returns the list of permission names currently assigned to a role."""
    with con.cursor() as cur:
        cur.execute(
            """
            SELECT p.PermissionName
            FROM rolepermissioninfo rp
            JOIN permissioninfo p ON rp.PermissionID = p.PermissionID
            WHERE rp.StatusID = %s
            ORDER BY p.PermissionName
            """,
            (status_id,),
        )
        return [row["PermissionName"] for row in cur.fetchall()]


def get_account_role_and_permissions(con, account_id) -> dict:
    """Returns {'Role': name, 'Permissions': [...]} for an account, looking
    the role up from the DB rather than trusting the token's claim."""
    with con.cursor() as cur:
        cur.execute("SELECT StatusID FROM accountinfo WHERE AccountID = %s", (account_id,))
        row = cur.fetchone()
        if row is None:
            return {"Role": None, "Permissions": []}
        status_id = row["StatusID"]
    return {
        "Role": role_name(status_id),
        "Permissions": get_permissions_for_status(con, status_id),
    }


async def get_current_account(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
) -> dict:
    """
    Validates the JWT and returns {"account_id": int, "status_id": int}.
    Use this on any route that just needs "is this a logged-in user".
    """
    token = credentials.credentials
    try:
        payload = decode_access_token(token)
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )

    account_id = payload.get("sub")
    status_id = payload.get("status_id")
    if account_id is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token payload")

    return {"account_id": int(account_id), "status_id": status_id}


async def require_superadmin(
    current=Depends(get_current_account),
) -> dict:
    """SUPERADMIN-only routes. Re-checks StatusID against the DB so revoked
    access takes effect immediately instead of waiting for token expiry."""
    con = getConnect()
    with con.cursor() as cur:
        cur.execute("SELECT StatusID FROM accountinfo WHERE AccountID = %s", (current["account_id"],))
        row = cur.fetchone()

    if row is None or row["StatusID"] != ROLE_SUPERADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="SUPERADMIN access required",
        )

    return current


async def require_developer(
    current=Depends(get_current_account),
) -> dict:
    """Backwards-compatible alias which maps the old developer (StatusID 3)
    to the SUPERADMIN role."""
    return await require_superadmin(current)


async def require_employee_or_superadmin(
    current=Depends(get_current_account),
) -> dict:
    """Routes accessible to both EMPLOYEE (StatusID 4) and SUPERADMIN
    (StatusID 3) accounts. Re-checks StatusID against the DB so revoked
    access takes effect immediately instead of waiting for token expiry."""
    con = getConnect()
    with con.cursor() as cur:
        cur.execute("SELECT StatusID FROM accountinfo WHERE AccountID = %s", (current["account_id"],))
        row = cur.fetchone()

    if row is None or row["StatusID"] not in (ROLE_SUPERADMIN, ROLE_EMPLOYEE):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="SUPERADMIN or EMPLOYEE access required",
        )

    return current


def require_permission(permission_name: str):
    """Dependency factory. Usage: `current=Depends(require_permission("create_event"))`.

    Checks the caller's role permissions against rolepermissioninfo and raises
    403 if the named permission is not assigned. SUPERADMIN implicitly passes.
    """
    async def _permission_dependency(
        current=Depends(get_current_account),
    ) -> dict:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute(
                "SELECT StatusID FROM accountinfo WHERE AccountID = %s",
                (current["account_id"],),
            )
            row = cur.fetchone()

        if row is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Account not found",
            )

        status_id = row["StatusID"]
        if status_id == ROLE_SUPERADMIN:
            return current

        with con.cursor() as cur:
            cur.execute(
                """
                SELECT COUNT(*) AS cnt
                FROM rolepermissioninfo rp
                JOIN permissioninfo p ON rp.PermissionID = p.PermissionID
                WHERE rp.StatusID = %s AND p.PermissionName = %s
                """,
                (status_id, permission_name),
            )
            row = cur.fetchone()

        if row is None or row["cnt"] == 0:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Permission '{permission_name}' required",
            )

        return current

    return _permission_dependency