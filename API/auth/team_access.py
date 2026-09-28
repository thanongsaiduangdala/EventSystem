"""
Shared team-access helpers used by the organizer "team member dashboard".

Organizer teams are *not* the same as the global account RBAC (accountstatusinfo
based). A person's team role lives on their organizermember row:

    TeamRoleID  1 = Staff / Employee
    TeamRoleID  2 = Volunteer
    TeamRoleID  3 = Page Designer
    TeamRoleID  4 = Org Admin
    TeamRoleID  5 = Org Owner

An account may hold memberships in several organizations, but at most one
live membership per organization (enforced by uq_organizer_active_member). The
account that created an organization is its Owner even before any membership
row exists (the migration backfills those rows, but the owner check does not
depend on it).

Event scoping is separate from org membership and lives in `eventstaff`: the
non-manager roles (Volunteer, Staff, Page Designer) are limited to the events
they are assigned to, while Admin and Owner are not event-scoped.

The helpers below are plain async functions a controller can await right after
it has validated its request, so a team member is allowed only for content in
their own organization.
"""
from fastapi import HTTPException, status

from DB.DBConnect import getConnect
from auth.dependencies import ROLE_SUPERADMIN

TEAM_ROLE_EMPLOYEE = 1
TEAM_ROLE_VOLUNTEER = 2
TEAM_ROLE_PAGE_DESIGNER = 3
TEAM_ROLE_ORG_ADMIN = 4
TEAM_ROLE_ORG_OWNER = 5

MEMBER_STATUS_ACTIVE = 2

EDITOR_ROLES = (TEAM_ROLE_PAGE_DESIGNER, TEAM_ROLE_ORG_ADMIN, TEAM_ROLE_ORG_OWNER)
MANAGER_ROLES = (TEAM_ROLE_ORG_ADMIN, TEAM_ROLE_ORG_OWNER)

# Roles allowed to work an event door: see attendees and run check-in.
# A Page Designer edits event content and has no attendee/check-in access.
DOOR_ROLES = (TEAM_ROLE_VOLUNTEER, TEAM_ROLE_EMPLOYEE)

# Roles allowed to go beyond check-in and decline/revoke a ticket.
TICKET_MANAGER_ROLES = (TEAM_ROLE_EMPLOYEE,)


def _status_has_permission(cur, status_id, permission_name: str) -> bool:
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
    return bool(row and row["cnt"])


def effective_role_for(con, account_id: int, org_id: int) -> list:
    """
    Team-roles the account effectively has inside an organization. Always
    includes Org Owner when the account created the organization; also adds
    the TeamRoleID of an active membership row if one exists.
    """
    roles = []
    with con.cursor() as cur:
        cur.execute(
            "SELECT CreatedByAccountID FROM eventorganizerinfo "
            "WHERE EventOrganizerID = %s",
            (org_id,),
        )
        row = cur.fetchone()
        if row and row["CreatedByAccountID"] == account_id:
            roles.append(TEAM_ROLE_ORG_OWNER)

        cur.execute(
            "SELECT TeamRoleID FROM organizermember "
            "WHERE AccountID = %s AND EventOrganizerID = %s "
            "AND MemberStatusID = %s",
            (account_id, org_id, MEMBER_STATUS_ACTIVE),
        )
        member_row = cur.fetchone()
        if member_row and member_row["TeamRoleID"] not in roles:
            roles.append(member_row["TeamRoleID"])
    return roles


def is_manager(roles) -> bool:
    return any(r in MANAGER_ROLES for r in roles)


def is_editor(roles) -> bool:
    return any(r in EDITOR_ROLES for r in roles)


def active_membership(con, account_id: int, org_id: int = None):
    """
    Enriched active membership row (role + org) for an account, or None.

    Pass org_id whenever the caller cares which organization the row belongs
    to. An account may hold memberships in several organizations, so without
    that filter this can return a row for a different org and make a
    legitimate member look like a stranger.
    """
    sql = """
        SELECT om.MemberID, om.AccountID, om.EventOrganizerID, om.TeamRoleID,
               om.MemberStatusID,
               tr.TeamRoleName,
               eo.EventOrganizerName, eo.EventOrganizerLogoPath,
               eo.EventOrganizerDiscription, eo.CreatedByAccountID
        FROM organizermember om
        LEFT JOIN teamrole tr ON tr.TeamRoleID = om.TeamRoleID
        LEFT JOIN eventorganizerinfo eo ON eo.EventOrganizerID = om.EventOrganizerID
        WHERE om.AccountID = %s AND om.MemberStatusID = %s
          AND eo.OrganizerStatusID = 2
    """
    args = [account_id, MEMBER_STATUS_ACTIVE]
    if org_id is not None:
        sql += " AND om.EventOrganizerID = %s"
        args.append(org_id)
    sql += " LIMIT 1"

    with con.cursor() as cur:
        cur.execute(sql, tuple(args))
        return cur.fetchone()


def active_memberships(con, account_id: int) -> list:
    """
    Every active membership the account holds (one per organization), owners
    first. Unlike active_membership() this does not silently drop the other
    organizations of an account that belongs to several.
    """
    with con.cursor() as cur:
        cur.execute(
            """
            SELECT om.MemberID, om.AccountID, om.EventOrganizerID, om.TeamRoleID,
                   om.MemberStatusID,
                   tr.TeamRoleName,
                   eo.EventOrganizerName, eo.EventOrganizerLogoPath,
                   eo.EventOrganizerDiscription, eo.CreatedByAccountID
            FROM organizermember om
            LEFT JOIN teamrole tr ON tr.TeamRoleID = om.TeamRoleID
            LEFT JOIN eventorganizerinfo eo ON eo.EventOrganizerID = om.EventOrganizerID
            WHERE om.AccountID = %s AND om.MemberStatusID = %s
              AND eo.OrganizerStatusID = 2
            ORDER BY (om.TeamRoleID = %s) DESC, om.MemberID ASC
            """,
            (account_id, MEMBER_STATUS_ACTIVE, TEAM_ROLE_ORG_OWNER),
        )
        return cur.fetchall()


def sync_owner_memberships(con, account_id: int) -> None:
    """
    Guarantees that every organization the account created has an active
    Org Owner membership row for it. Organizations created after the
    team-dashboard migration ran never got the backfilled row, which left
    their owners with an empty team dashboard.
    """
    with con.cursor() as cur:
        cur.execute(
            "SELECT eo.EventOrganizerID FROM eventorganizerinfo eo "
            "WHERE eo.CreatedByAccountID = %s AND eo.OrganizerStatusID = 2 "
            "AND NOT EXISTS ("
            "  SELECT 1 FROM organizermember om "
            "  WHERE om.AccountID = %s AND om.EventOrganizerID = eo.EventOrganizerID "
            "  AND om.MemberStatusID = %s)",
            (account_id, account_id, MEMBER_STATUS_ACTIVE),
        )
        missing = [r["EventOrganizerID"] for r in cur.fetchall()]
        for org_id in missing:
            # A Pending/Declined row still occupies the unique slot, so
            # promote it instead of inserting a duplicate.
            cur.execute(
                "SELECT MemberID FROM organizermember "
                "WHERE AccountID = %s AND EventOrganizerID = %s AND MemberStatusID != 4",
                (account_id, org_id),
            )
            row = cur.fetchone()
            if row:
                cur.execute(
                    "UPDATE organizermember SET TeamRoleID = %s, MemberStatusID = %s "
                    "WHERE MemberID = %s",
                    (TEAM_ROLE_ORG_OWNER, MEMBER_STATUS_ACTIVE, row["MemberID"]),
                )
            else:
                cur.execute(
                    "INSERT INTO organizermember "
                    "(AccountID, EventOrganizerID, TeamRoleID, MemberStatusID) "
                    "VALUES (%s, %s, %s, %s)",
                    (account_id, org_id, TEAM_ROLE_ORG_OWNER, MEMBER_STATUS_ACTIVE),
                )
        if missing:
            con.commit()


def ensure_member_row(con, account_id: int, org_id: int, team_role_id: int = TEAM_ROLE_ORG_OWNER) -> int:
    """
    Returns the MemberID of the account's active row for org_id, creating one
    if it is missing (used so the org owner can always be recorded as the
    person who performed a check-in, even before the backfill ran).
    """
    with con.cursor() as cur:
        cur.execute(
            "SELECT MemberID FROM organizermember "
            "WHERE AccountID = %s AND EventOrganizerID = %s AND MemberStatusID = %s",
            (account_id, org_id, MEMBER_STATUS_ACTIVE),
        )
        row = cur.fetchone()
        if row:
            return row["MemberID"]

        cur.execute(
            "INSERT INTO organizermember "
            "(AccountID, EventOrganizerID, TeamRoleID, MemberStatusID) "
            "VALUES (%s, %s, %s, %s)",
            (account_id, org_id, team_role_id, MEMBER_STATUS_ACTIVE),
        )
        con.commit()
        return cur.lastrowid


def event_org_id(con, event_id: int):
    with con.cursor() as cur:
        cur.execute("SELECT EventOrganizerID FROM eventinfo WHERE EventID = %s", (event_id,))
        row = cur.fetchone()
        return row["EventOrganizerID"] if row else None


def _forbidden(detail: str):
    return HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=detail)


async def ensure_team_access(con, current: dict, event_id: int) -> dict:
    """
    The caller may see attendee data / run check-in for an event when they are:
      - a manager of the event's organization (Admin / Owner / the creator), or
      - assigned to that event as a team member (volunteer / staff / designer).
    Returns the caller's active membership row (or None when they reached the
    event through ownership).
    """
    account_id = current["account_id"]
    org_id = event_org_id(con, event_id)
    if org_id is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

    roles = effective_role_for(con, account_id, org_id)
    if is_manager(roles):
        return active_membership(con, account_id, org_id)

    member = active_membership(con, account_id, org_id)
    if member is None or member["EventOrganizerID"] != org_id:
        raise _forbidden("You must be assigned to this event to view its attendees")
    if member["TeamRoleID"] not in DOOR_ROLES:
        raise _forbidden("This role cannot view attendees or run check-in")

    with con.cursor() as cur:
        cur.execute(
            "SELECT COUNT(*) AS cnt FROM eventstaff "
            "WHERE EventID = %s AND MemberID = %s",
            (event_id, member["MemberID"]),
        )
        row = cur.fetchone()
        if not row or row["cnt"] == 0:
            raise _forbidden("You are not assigned to this event")
    return member


async def ensure_attendee_list_access(con, current: dict, event_id: int) -> dict:
    """
    Browsing the event's attendee list is a Staff+ capability. A Volunteer is
    limited to resolving a single attendee from a scanned ticket (see
    ensure_team_access), because the list exposes contact details and national
    ID for every attendee.
    """
    account_id = current["account_id"]
    org_id = event_org_id(con, event_id)
    if org_id is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

    roles = effective_role_for(con, account_id, org_id)
    if is_manager(roles):
        return active_membership(con, account_id, org_id)

    member = active_membership(con, account_id, org_id)
    if member is None or member["EventOrganizerID"] != org_id:
        raise _forbidden("You must be assigned to this event to view its attendees")
    if member["TeamRoleID"] not in TICKET_MANAGER_ROLES:
        raise _forbidden("Volunteers cannot browse the attendee list")

    with con.cursor() as cur:
        cur.execute(
            "SELECT COUNT(*) AS cnt FROM eventstaff "
            "WHERE EventID = %s AND MemberID = %s",
            (event_id, member["MemberID"]),
        )
        row = cur.fetchone()
        if not row or row["cnt"] == 0:
            raise _forbidden("You are not assigned to this event")
    return member


async def ensure_staff_or_manager(con, current: dict, event_id: int) -> None:
    """Revoking/declining tickets is a Staff+ capability (never a Volunteer)."""
    account_id = current["account_id"]
    org_id = event_org_id(con, event_id)
    if org_id is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

    roles = effective_role_for(con, account_id, org_id)
    if is_manager(roles):
        return

    member = active_membership(con, account_id, org_id)
    if member is None or member["EventOrganizerID"] != org_id:
        raise _forbidden("Only staff assigned to this event may manage tickets")
    if member["TeamRoleID"] not in TICKET_MANAGER_ROLES:
        raise _forbidden("Only Staff / Employee may decline or revoke tickets")

    with con.cursor() as cur:
        cur.execute(
            "SELECT COUNT(*) AS cnt FROM eventstaff "
            "WHERE EventID = %s AND MemberID = %s",
            (event_id, member["MemberID"]),
        )
        row = cur.fetchone()
        if not row or row["cnt"] == 0:
            raise _forbidden("You are not assigned to this event")
    return None


async def ensure_org_manager(con, current: dict, org_id: int) -> dict:
    """Only Admin / Owner / creator may manage the team and org settings."""
    account_id = current["account_id"]
    roles = effective_role_for(con, account_id, org_id)
    if not is_manager(roles):
        raise _forbidden("Admin or Owner access is required")
    return active_membership(con, account_id, org_id)


async def ensure_org_owner(con, current: dict, org_id: int) -> None:
    account_id = current["account_id"]
    with con.cursor() as cur:
        cur.execute(
            "SELECT CreatedByAccountID FROM eventorganizerinfo "
            "WHERE EventOrganizerID = %s",
            (org_id,),
        )
        row = cur.fetchone()
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organization not found")
    roles = effective_role_for(con, account_id, org_id)
    if row["CreatedByAccountID"] != account_id and TEAM_ROLE_ORG_OWNER not in roles:
        raise _forbidden("Only the organization owner can do this")


async def ensure_event_editor(con, current: dict, event_id: int, permission: str, delete: bool = False) -> None:
    """
    Someone may modify event content when they are:
      - a SUPERADMIN (global role), or
      - an Admin / Owner of the event's organization (never event-scoped), or
      - a Page Designer assigned to this event (`eventstaff`).
    A global permission is never a cross-org backdoor: a non-editor account
    may only use it to maintain content of organizations it actually belongs
    to. Deletion always requires Admin / Owner.
    """
    account_id = current["account_id"]
    org_id = event_org_id(con, event_id)
    if org_id is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

    with con.cursor() as cur:
        cur.execute("SELECT StatusID FROM accountinfo WHERE AccountID = %s", (account_id,))
        status_row = cur.fetchone()

    if status_row is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Account not found")
    status_id = status_row["StatusID"]
    if status_id == ROLE_SUPERADMIN:
        return

    con2_roles = effective_role_for(con, account_id, org_id)
    if is_manager(con2_roles):
        return

    if is_editor(con2_roles):
        member = active_membership(con, account_id, org_id)
        if member is None or member["EventOrganizerID"] != org_id:
            raise _forbidden("You must be a member of this event's organization")
        with con.cursor() as cur:
            cur.execute(
                "SELECT COUNT(*) AS cnt FROM eventstaff "
                "WHERE EventID = %s AND MemberID = %s",
                (event_id, member["MemberID"]),
            )
            row = cur.fetchone()
            if not row or row["cnt"] == 0:
                raise _forbidden("You are not assigned to this event")

        if delete:
            raise _forbidden("Only Admins and the Owner may delete event content")
        return

    member = active_membership(con, account_id, org_id)
    if member is None or member["EventOrganizerID"] != org_id:
        raise _forbidden(
            f"Permission '{permission}' or a Page Designer / Admin / Owner role is required"
        )
    with con.cursor() as cur:
        if not _status_has_permission(cur, status_id, permission):
            raise _forbidden(
                f"Permission '{permission}' or a Page Designer / Admin / Owner role is required"
            )
    if delete:
        raise _forbidden("Only Admins and the Owner may delete event content")
    return


async def ensure_org_editor(con, current: dict, org_id: int, permission: str) -> None:
    """
    Same as ensure_event_editor but for actions that target an organization
    before an event exists (e.g. creating an event). Page Designer can not
    create events -- only Managers can, plus anyone with the global permission.
    """
    account_id = current["account_id"]
    roles = effective_role_for(con, account_id, org_id)
    with con.cursor() as cur:
        cur.execute("SELECT StatusID FROM accountinfo WHERE AccountID = %s", (account_id,))
        status_row = cur.fetchone()

    if status_row is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Account not found")
    status_id = status_row["StatusID"]
    if status_id == ROLE_SUPERADMIN:
        return
    with con.cursor() as cur:
        if _status_has_permission(cur, status_id, permission):
            return
        if is_manager(roles):
            return
    raise _forbidden(f"Permission '{permission}' or an Admin / Owner role is required")