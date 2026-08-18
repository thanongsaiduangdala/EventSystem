from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError
from auth.jwt_handler import decode_access_token
from DB.DBConnect import getConnect

bearer_scheme = HTTPBearer()


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


async def require_developer(
    current=Depends(get_current_account),
) -> dict:
    """
    Use this on developer-only routes (event/organizer CRUD, etc).
    Re-checks StatusID against the DB rather than trusting the token's claim,
    so revoked access takes effect immediately instead of waiting for token expiry.
    """
    con = getConnect()
    with con.cursor() as cur:
        cur.execute("SELECT StatusID FROM accountinfo WHERE AccountID = %s", (current["account_id"],))
        row = cur.fetchone()

    if row is None or row["StatusID"] != 3:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Developer access required",
        )

    return current