import pymysql
import bcrypt
from typing import Optional
from fastapi import HTTPException, status, Depends, Query
from DB.DBConnect import getConnect
from models.schema import AddAccountInfoRequest, UpdateAccountNoPasswordInfoRequest
from auth.dependencies import require_permission

async def create_account(req_data: AddAccountInfoRequest, current=Depends(require_permission("manage_accounts"))):
    try:
        con = getConnect()
        with con.cursor() as cur:

            pwd_byte = req_data.PasswordEnc.encode("utf-8")
            salt = bcrypt.gensalt(rounds=10)
            hash_pwd = bcrypt.hashpw(pwd_byte, salt).decode("utf-8")

            sql = """
                INSERT INTO accountinfo
                (FirstName, LastName, PhoneNum, Email, StatusID, PasswordEnc)
                VALUES (%s, %s, %s, %s, %s, %s)
            """
            cur.execute(sql, (
                req_data.FirstName,
                req_data.LastName,
                req_data.PhoneNum,
                req_data.Email,
                req_data.StatusID,
                hash_pwd
            ))
            account_id = cur.lastrowid
            con.commit()

        return {"msg": "Account created successfully", "account_id": account_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_all_accounts(current=Depends(require_permission("manage_accounts"))):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("""
                SELECT * FROM accountinfo
            """)
            Accounts = cur.fetchall()

        return {"Accounts": Accounts}

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_account_by_id(account_id: int, current=Depends(require_permission("manage_accounts"))):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("""
                SELECT * FROM accountinfo WHERE AccountID = %s
            """, (account_id,))
            Accounts = cur.fetchone()

        if Accounts is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Account not found")

        return {"Account": Accounts}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def update_account(req_data: UpdateAccountNoPasswordInfoRequest, current=Depends(require_permission("manage_accounts"))):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                UPDATE accountinfo
                SET FirstName = %s,
                    LastName = %s,
                    PhoneNum = %s,
                    Email = %s,
                    StatusID = %s
                WHERE AccountID = %s
            """
            cur.execute(sql, (
                req_data.FirstName,
                req_data.LastName,
                req_data.PhoneNum,
                req_data.Email,
                req_data.StatusID,
                req_data.AccountID
            ))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Account not found")

            con.commit()

        return {"msg": "account updated successfully", "account_id": req_data.AccountID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


# ---------------------------------------------------------------------------
# Delete account + foreign-key handling
#
# Every table that points at accountinfo is discovered at runtime from
# information_schema, so this keeps working when you add new tables later.
# Table / column names only ever come from information_schema (never from the
# request), so putting them into SQL with backticks is safe.
# ---------------------------------------------------------------------------

MAX_DEPTH = 10  # safety net against runaway recursion

DELETE_MODES = {"normal", "selective", "cascade", "force"}

# Friendly names shown in the Flutter pop-up. Anything missing falls back to
# "table.column", so this list is purely cosmetic.
COLUMN_LABELS = {
    ("eventorganizerinfo", "createdbyaccountid"): "Organizers created by this account",
    ("organizermember", "accountid"): "Organizer team memberships",
    ("ordersinfo", "accountid"): "Orders",
    ("identityverification", "accountid"): "Identity verifications submitted by this account",
    ("identityverification", "reviewedbyaccountid"): "Identity verifications reviewed by this account",
    ("accountcategoryinfo", "accountid"): "Favourite categories",
    ("wishlistinfo", "accountid"): "Wishlist items",
    ("followinfo", "accountid"): "Followed organizers",
    ("eventviewinfo", "accountid"): "Event view history",
    ("notificationinfo", "accountid"): "Notifications",
    ("eventinfo", "eventorganizerid"): "Events of the organizer",
    ("organizermember", "eventorganizerid"): "Team members of the organizer",
    ("followinfo", "eventorganizerid"): "Followers of the organizer",
    ("eventstaff", "memberid"): "Event staff assignments",
    ("ticketattendence", "orderid"): "Tickets / attendees",
    ("attendeeresponse", "attendeeid"): "Attendee answers",
    ("ticketcheckin", "attendeeid"): "Ticket check-ins",
    ("ticketcheckin", "checkedinbymemberid"): "Check-ins scanned by the member",
    ("ticketcheckin", "eventid"): "Check-ins for the event",
    ("tickettype", "eventid"): "Ticket types of the event",
    ("eventstaff", "eventid"): "Staff of the event",
    ("eventcategoryinfo", "eventid"): "Categories of the event",
    ("eventimageinfo", "eventid"): "Images of the event",
    ("eventquestioninfo", "eventid"): "Questions of the event",
    ("eventsponserinfo", "eventid"): "Sponsors of the event",
    ("wishlistinfo", "eventid"): "Wishlist entries for the event",
    ("eventviewinfo", "eventid"): "Views of the event",
    ("attendeeresponse", "eventquestionid"): "Answers to the question",
    ("ticketattendence", "tickettypeid"): "Tickets of this ticket type",
}


def _label(table: str, column: str) -> str:
    return COLUMN_LABELS.get((table.lower(), column.lower()), f"{table}.{column}")


def _fks_referencing(cur, table: str, cache: dict) -> list:
    """Foreign keys (in this database) whose parent is `table`."""
    if table in cache:
        return cache[table]
    cur.execute(
        """
        SELECT kcu.TABLE_NAME             AS child_table,
               kcu.COLUMN_NAME            AS child_column,
               kcu.REFERENCED_COLUMN_NAME AS parent_column,
               rc.DELETE_RULE             AS delete_rule,
               c.IS_NULLABLE              AS is_nullable
        FROM information_schema.KEY_COLUMN_USAGE kcu
        JOIN information_schema.REFERENTIAL_CONSTRAINTS rc
          ON rc.CONSTRAINT_SCHEMA = kcu.CONSTRAINT_SCHEMA
         AND rc.CONSTRAINT_NAME   = kcu.CONSTRAINT_NAME
         AND rc.TABLE_NAME        = kcu.TABLE_NAME
        JOIN information_schema.COLUMNS c
          ON c.TABLE_SCHEMA = kcu.TABLE_SCHEMA
         AND c.TABLE_NAME   = kcu.TABLE_NAME
         AND c.COLUMN_NAME  = kcu.COLUMN_NAME
        WHERE kcu.TABLE_SCHEMA = DATABASE()
          AND kcu.REFERENCED_TABLE_SCHEMA = DATABASE()
          AND kcu.REFERENCED_TABLE_NAME = %s
        ORDER BY kcu.TABLE_NAME, kcu.COLUMN_NAME
        """,
        (table,),
    )
    cache[table] = list(cur.fetchall())
    return cache[table]


def _rule(fk: dict) -> str:
    return (fk["delete_rule"] or "NO ACTION").upper()


def _is_blocking(fk: dict) -> bool:
    """True when MySQL refuses to delete the parent row while children exist."""
    return _rule(fk) in ("NO ACTION", "RESTRICT")


def _action(fk: dict) -> str:
    """What we do with the child rows: 'delete' them or 'set_null' (unlink)."""
    rule = _rule(fk)
    if rule == "SET NULL":
        return "set_null"
    if rule == "CASCADE":
        return "delete"
    # NO ACTION / RESTRICT: keep the row if the column allows NULL, else delete it
    return "set_null" if fk["is_nullable"] == "YES" else "delete"


def _placeholders(values) -> str:
    return ",".join(["%s"] * len(values))


def _distinct_values(cur, table, where_col, where_vals, select_col) -> list:
    cur.execute(
        f"SELECT DISTINCT `{select_col}` AS v FROM `{table}` "
        f"WHERE `{where_col}` IN ({_placeholders(where_vals)}) AND `{select_col}` IS NOT NULL",
        tuple(where_vals),
    )
    return [row["v"] for row in cur.fetchall()]


def _count_rows(cur, table, col, vals) -> int:
    cur.execute(
        f"SELECT COUNT(*) AS n FROM `{table}` WHERE `{col}` IN ({_placeholders(vals)})",
        tuple(vals),
    )
    return int(cur.fetchone()["n"])


def _build_dependency_tree(cur, table, where_col, where_vals, depth, path, cache) -> list:
    """Describe everything that hangs off the rows `table.where_col IN where_vals`."""
    nodes = []
    if depth > MAX_DEPTH:
        return nodes
    for fk in _fks_referencing(cur, table, cache):
        key = (fk["child_table"], fk["child_column"])
        if key in path:
            continue
        ref_vals = _distinct_values(cur, table, where_col, where_vals, fk["parent_column"])
        if not ref_vals:
            continue
        count = _count_rows(cur, fk["child_table"], fk["child_column"], ref_vals)
        if count == 0:
            continue
        action = _action(fk)
        node = {
            "key": f"{fk['child_table']}.{fk['child_column']}",
            "table": fk["child_table"],
            "column": fk["child_column"],
            "label": _label(fk["child_table"], fk["child_column"]),
            "count": count,
            "rule": _rule(fk),
            "blocking": _is_blocking(fk),
            "action": action,
            "children": [],
        }
        if action == "delete":
            node["children"] = _build_dependency_tree(
                cur, fk["child_table"], fk["child_column"], ref_vals, depth + 1, path | {key}, cache
            )
        nodes.append(node)
    return nodes


def _clear_children(cur, table, where_col, where_vals, depth, path, cache, only=None):
    """Delete (or unlink) every row that references `table.where_col IN where_vals`.
    `only` (set of 'table.column') limits the top level to the chosen links."""
    if depth > MAX_DEPTH:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Linked data is nested too deeply to delete automatically",
        )
    for fk in _fks_referencing(cur, table, cache):
        key = (fk["child_table"], fk["child_column"])
        if key in path:
            continue
        if only is not None and f"{fk['child_table']}.{fk['child_column']}" not in only:
            continue
        ref_vals = _distinct_values(cur, table, where_col, where_vals, fk["parent_column"])
        if not ref_vals:
            continue
        if _action(fk) == "set_null":
            cur.execute(
                f"UPDATE `{fk['child_table']}` SET `{fk['child_column']}` = NULL "
                f"WHERE `{fk['child_column']}` IN ({_placeholders(ref_vals)})",
                tuple(ref_vals),
            )
        else:
            _delete_rows(cur, fk["child_table"], fk["child_column"], ref_vals, depth + 1, path | {key}, cache)


def _delete_rows(cur, table, where_col, where_vals, depth, path, cache):
    """Delete rows of `table` (children first)."""
    _clear_children(cur, table, where_col, where_vals, depth, path, cache)
    cur.execute(
        f"DELETE FROM `{table}` WHERE `{where_col}` IN ({_placeholders(where_vals)})",
        tuple(where_vals),
    )


def _dependency_conflict(account_id: int, message: str) -> HTTPException:
    # The Flutter app looks for this code to open the "linked data" pop-up.
    return HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail={
            "code": "ACCOUNT_HAS_DEPENDENCIES",
            "message": message,
            "account_id": account_id,
        },
    )


async def get_account_dependencies(account_id: int, current=Depends(require_permission("manage_accounts"))):
    """Preview: what is linked to this account (nothing is changed)."""
    con = getConnect()
    if con is None:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Database connection failed")
    try:
        with con.cursor() as cur:
            cur.execute(
                "SELECT AccountID, FirstName, LastName, Email FROM accountinfo WHERE AccountID = %s",
                (account_id,),
            )
            acc = cur.fetchone()
            if acc is None:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Account not found")

            nodes = _build_dependency_tree(cur, "accountinfo", "AccountID", [account_id], 0, frozenset(), {})

        return {
            "account_id": account_id,
            "account_name": f"{acc['FirstName']} {acc['LastName']}".strip(),
            "email": acc["Email"],
            "has_blocking": any(n["blocking"] for n in nodes),
            "dependencies": nodes,
        }
    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})
    finally:
        con.close()


async def delete_account(
    account_id: int,
    mode: str = Query("normal", description="normal | selective | cascade | force"),
    targets: Optional[str] = Query(None, description="selective mode: comma separated 'table.column' links to delete"),
    current=Depends(require_permission("manage_accounts")),
):
    """
    normal    - plain delete; answers 409 ACCOUNT_HAS_DEPENDENCIES if rows still point at the account
    selective - delete only the chosen linked rows (and what hangs off them); the account itself is
                deleted too once nothing blocks it any more, otherwise answers 409 again
    cascade   - delete the account and everything connected to it
    force     - delete ONLY the account, ignoring foreign keys (leaves orphaned rows behind)
    """
    mode = (mode or "normal").lower()
    if mode not in DELETE_MODES:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Unknown delete mode '{mode}'")

    con = getConnect()
    if con is None:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Database connection failed")

    try:
        with con.cursor() as cur:
            cur.execute("SELECT AccountID FROM accountinfo WHERE AccountID = %s", (account_id,))
            if cur.fetchone() is None:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Account not found")

            cache = {}
            if mode == "selective":
                chosen = {t.strip() for t in (targets or "").split(",") if t.strip()}
                if not chosen:
                    raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No linked data was selected")
                valid = {f"{fk['child_table']}.{fk['child_column']}" for fk in _fks_referencing(cur, "accountinfo", cache)}
                unknown = chosen - valid
                if unknown:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=f"Unknown linked data: {', '.join(sorted(unknown))}",
                    )
                _clear_children(cur, "accountinfo", "AccountID", [account_id], 0, frozenset(), cache, only=chosen)
                # Keep the chosen deletions even if the account itself is still blocked
                # by other links, so the admin can clean up step by step.
                con.commit()
                try:
                    cur.execute("DELETE FROM accountinfo WHERE AccountID = %s", (account_id,))
                except pymysql.IntegrityError as err:
                    con.rollback()
                    if err.args and err.args[0] in (1451, 1217):
                        raise _dependency_conflict(
                            account_id,
                            "The selected records were deleted, but the account is still linked to other records.",
                        )
                    raise

            elif mode == "cascade":
                _delete_rows(cur, "accountinfo", "AccountID", [account_id], 0, frozenset(), cache)

            elif mode == "force":
                cur.execute("SET FOREIGN_KEY_CHECKS = 0")
                try:
                    cur.execute("DELETE FROM accountinfo WHERE AccountID = %s", (account_id,))
                    con.commit()
                finally:
                    cur.execute("SET FOREIGN_KEY_CHECKS = 1")

            else:  # normal
                cur.execute("DELETE FROM accountinfo WHERE AccountID = %s", (account_id,))

            con.commit()

        return {"msg": "Account deleted successfully", "account_id": account_id, "mode": mode}

    except HTTPException:
        con.rollback()
        raise
    except pymysql.IntegrityError as err:
        con.rollback()
        if err.args and err.args[0] in (1451, 1217):  # row is referenced by a foreign key
            raise _dependency_conflict(account_id, "This account is still linked to other records.")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})
    except pymysql.MySQLError as err:
        con.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})
    finally:
        con.close()
