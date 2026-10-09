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


# Shown when the token was issued before the account's role changed (for
# example an admin approved the identity verification after the user logged
# in). The JWT carries the role from login time, so the user has to log in
# again to get a token that matches their new role.
RELOGIN_REQUIRED_MESSAGE = (
    "Your account access was updated. Please log out and log back in to "
    "use organization pages."
)


def token_is_stale(token_status_id, db_status_id) -> bool:
    """True when the role inside the JWT no longer matches the account's
    current role in the database."""
    return db_status_id is not None and token_status_id != db_status_id


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


async def get_fresh_account(
    current=Depends(get_current_account),
) -> dict:
    """Like get_current_account, but also rejects a token whose role is out
    of date (see RELOGIN_REQUIRED_MESSAGE). Use it on organization/team
    routes so a freshly approved organizer cannot use them until they log
    out and back in."""
    con = getConnect()
    try:
        with con.cursor() as cur:
            cur.execute(
                "SELECT StatusID FROM accountinfo WHERE AccountID = %s",
                (current["account_id"],),
            )
            row = cur.fetchone()
    finally:
        con.close()

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Account not found",
        )
    if token_is_stale(current["status_id"], row["StatusID"]):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=RELOGIN_REQUIRED_MESSAGE,
        )
    return current


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


def require_reviewer_or_permission(permission_name: str):
    """Like require_permission, but EMPLOYEE and SUPERADMIN accounts always
    pass. Used for review screens (e.g. the Employee Dashboard's Events tab)
    that employees need without being granted the organizer-only permission
    (create_event / update_event) that would also let them create events.
    Everyone else still needs `permission_name`."""
    fallback = require_permission(permission_name)

    async def _dependency(
        current=Depends(get_current_account),
    ) -> dict:
        con = getConnect()
        try:
            with con.cursor() as cur:
                cur.execute(
                    "SELECT StatusID FROM accountinfo WHERE AccountID = %s",
                    (current["account_id"],),
                )
                row = cur.fetchone()
        finally:
            con.close()

        if row is not None and row["StatusID"] in (ROLE_SUPERADMIN, ROLE_EMPLOYEE):
            return current
        return await fallback(current)

    return _dependency


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

        # The role was upgraded after this token was issued (e.g. identity
        # verification approved): only grant what the token's own role
        # already allowed until the user logs in again.
        token_status_id = current.get("status_id")
        if token_is_stale(token_status_id, status_id):
            with con.cursor() as cur:
                cur.execute(
                    """
                    SELECT COUNT(*) AS cnt
                    FROM rolepermissioninfo rp
                    JOIN permissioninfo p ON rp.PermissionID = p.PermissionID
                    WHERE rp.StatusID = %s AND p.PermissionName = %s
                    """,
                    (token_status_id, permission_name),
                )
                token_row = cur.fetchone()
            if token_row is None or token_row["cnt"] == 0:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=RELOGIN_REQUIRED_MESSAGE,
                )

        return current

    return _permission_dependency