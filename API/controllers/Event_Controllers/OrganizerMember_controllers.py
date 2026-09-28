import pymysql
from fastapi import HTTPException, status, Depends
from DB.DBConnect import getConnect
from models.schema import (
    AddOrganizerMemberRequest,
    UpdateOrganizerMemberRequest,
    InviteOrganizerMemberRequest,
    ChangeMemberRoleRequest,
    TransferOwnershipRequest,
    AssignMemberEventRequest,
    UnassignMemberEventRequest,
)
from auth.dependencies import require_permission, get_current_account
from auth.team_access import (
    TEAM_ROLE_ORG_OWNER,
    active_membership,
    ensure_org_manager,
    ensure_org_owner,
)
from controllers.Event_Controllers.Notification_controllers import notify_accounts

# MemberStatusID constants (mirror memberstatusinfo rows).
MEMBER_STATUS_PENDING = 1
MEMBER_STATUS_ACTIVE = 2
MEMBER_STATUS_DECLINED = 3
MEMBER_STATUS_REMOVED = 4


def _current_orgs(cur, account_id) -> list:
    """
    EventOrganizerIDs created by an account. Team members are scoped to the
    organizers the dashboard account actually owns, so one organizer cannot
    see another's member list through this endpoint.
    """
    cur.execute(
        "SELECT EventOrganizerID FROM eventorganizerinfo WHERE CreatedByAccountID = %s",
        (account_id,),
    )
    return [row["EventOrganizerID"] for row in cur.fetchall()]


def _organization_name(cur, event_organizer_id: int) -> str:
    cur.execute(
        "SELECT EventOrganizerName FROM eventorganizerinfo WHERE EventOrganizerID = %s",
        (event_organizer_id,),
    )
    row = cur.fetchone()
    return row["EventOrganizerName"] if row else "this organization"


def _role_name(cur, team_role_id) -> str:
    if team_role_id is None:
        return ""
    cur.execute(
        "SELECT TeamRoleName FROM teamrole WHERE TeamRoleID = %s",
        (team_role_id,),
    )
    row = cur.fetchone()
    return row["TeamRoleName"] if row else "Member"


def _member_row(cur, member_id: int):
    cur.execute("SELECT * FROM organizermember WHERE MemberID = %s", (member_id,))
    return cur.fetchone()


async def create_organizermember(req_data: AddOrganizerMemberRequest, current=Depends(require_permission("manage_event_members"))):
    try:
        con = getConnect()
        with con.cursor() as cur:
            # An account may only belong to one organization at a time.
            # Removed (MemberStatusID = 4) rows do not count, so a former
            # member can be re-added.
            cur.execute(
                "SELECT MemberID FROM organizermember WHERE AccountID = %s AND MemberStatusID != %s",
                (req_data.AccountID, MEMBER_STATUS_REMOVED),
            )
            if cur.fetchone() is not None:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="This account already belongs to an organization",
                )

            sql = """
                INSERT INTO organizermember
                (AccountID, EventOrganizerID, TeamRoleID, MemberStatusID)
                VALUES (%s, %s, %s, %s)
            """
            cur.execute(sql, (
                req_data.AccountID,
                req_data.EventOrganizerID,
                req_data.TeamRoleID,
                req_data.MemberStatusID,
            ))
            con.commit()
            Member_ID = cur.lastrowid

        return {"msg": "Organizer member created successfully", "MemberID": Member_ID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_all_OrganizerMembers(current=Depends(require_permission("view_events"))):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM organizermember"
            cur.execute(sql)
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_organizermember_by_id(member_id: int, current=Depends(require_permission("view_events"))):
    """
    Single member, enriched with the linked account, role, membership status
    and the organization being joined -- powers the invite/join page.
    """
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                SELECT om.MemberID, om.AccountID, om.EventOrganizerID, om.TeamRoleID,
                       om.MemberStatusID,
                       a.FirstName, a.LastName, a.Email,
                       tr.TeamRoleName, ms.StatusName,
                       eo.EventOrganizerName, eo.EventOrganizerLogoPath,
                       eo.EventOrganizerDiscription, eo.CreatedByAccountID
                FROM organizermember om
                LEFT JOIN accountinfo a ON a.AccountID = om.AccountID
                LEFT JOIN teamrole tr ON tr.TeamRoleID = om.TeamRoleID
                LEFT JOIN memberstatusinfo ms ON ms.MemberStatusID = om.MemberStatusID
                LEFT JOIN eventorganizerinfo eo ON eo.EventOrganizerID = om.EventOrganizerID
                WHERE om.MemberID = %s
            """
            cur.execute(sql, (member_id,))
            row = cur.fetchone()

        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organizer member not found")

        return row

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_organizermembers_with_accounts(current=Depends(require_permission("manage_event_members"))):
    """
    Every membership row enriched with account name/email, role name, status
    name and organization name, scoped to the organizers the caller owns.
    Used by the organizer dashboard to render the team with invite states.
    """
    try:
        con = getConnect()
        with con.cursor() as cur:
            owner_ids = _current_orgs(cur, current["account_id"])
            if not owner_ids:
                return []

            placeholders = ", ".join(["%s"] * len(owner_ids))
            sql = f"""
                SELECT om.MemberID, om.AccountID, om.EventOrganizerID, om.TeamRoleID,
                       om.MemberStatusID,
                       a.FirstName, a.LastName, a.Email,
                       tr.TeamRoleName, ms.StatusName,
                       eo.EventOrganizerName
                FROM organizermember om
                LEFT JOIN accountinfo a ON a.AccountID = om.AccountID
                LEFT JOIN teamrole tr ON tr.TeamRoleID = om.TeamRoleID
                LEFT JOIN memberstatusinfo ms ON ms.MemberStatusID = om.MemberStatusID
                LEFT JOIN eventorganizerinfo eo ON eo.EventOrganizerID = om.EventOrganizerID
                WHERE om.EventOrganizerID IN ({placeholders})
                ORDER BY om.MemberStatusID ASC, om.MemberID DESC
            """
            cur.execute(sql, owner_ids)
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def invite_organizermember(req_data: InviteOrganizerMemberRequest, current=Depends(get_current_account)):
    """
    Invites an existing account (by email) to an organization. Creates a
    Pending membership row and notifies the invitee, whose notification
    deep-links to the join page. Admin / Owner of the organization only.
    """
    try:
        con = getConnect()
        await ensure_org_manager(con, current, req_data.EventOrganizerID)
        with con.cursor() as cur:
            cur.execute(
                "SELECT AccountID FROM accountinfo WHERE LOWER(Email) = %s",
                (req_data.Email.lower(),),
            )
            account_row = cur.fetchone()
            if not account_row:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No account found with this email")

            account_id = account_row["AccountID"]
            if account_id == current["account_id"]:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="You cannot invite your own account")

            cur.execute(
                "SELECT EventOrganizerID FROM eventorganizerinfo WHERE EventOrganizerID = %s",
                (req_data.EventOrganizerID,),
            )
            if cur.fetchone() is None:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organization not found")

            cur.execute(
                "SELECT MemberID FROM organizermember WHERE AccountID = %s AND MemberStatusID != %s",
                (account_id, MEMBER_STATUS_REMOVED),
            )
            if cur.fetchone() is not None:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="This account is already part of (or invited to) an organization",
                )

            cur.execute(
                "SELECT TeamRoleID FROM teamrole WHERE TeamRoleID = %s",
                (req_data.TeamRoleID,),
            )
            if cur.fetchone() is None:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Team role not found")

            if req_data.TeamRoleID == TEAM_ROLE_ORG_OWNER:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="The Org Owner role can only be granted by transferring ownership",
                )

            sql = """
                INSERT INTO organizermember
                (AccountID, EventOrganizerID, TeamRoleID, MemberStatusID)
                VALUES (%s, %s, %s, %s)
            """
            cur.execute(sql, (
                account_id,
                req_data.EventOrganizerID,
                req_data.TeamRoleID,
                MEMBER_STATUS_PENDING,
            ))
            con.commit()
            member_id = cur.lastrowid

            org_name = _organization_name(cur, req_data.EventOrganizerID)
            role_name = _role_name(cur, req_data.TeamRoleID)
            notify_accounts(
                [account_id],
                "system",
                f"You're invited to join '{org_name}'",
                f"{org_name} has invited you to join their team as {role_name}. Tap to review the invitation.",
                link=f"org_invite:{member_id}",
            )

        return {"msg": "Invitation sent successfully", "MemberID": member_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def accept_organizermember(member_id: int, current=Depends(get_current_account)):
    """Accept a pending invitation. Only the invited account may accept."""
    try:
        con = getConnect()
        with con.cursor() as cur:
            row = _member_row(cur, member_id)
            if not row:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organizer member not found")
            if row["AccountID"] != current["account_id"]:
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="This invitation is not for you")
            if row["MemberStatusID"] != MEMBER_STATUS_PENDING:
                raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="This invitation is no longer pending")

            cur.execute(
                "UPDATE organizermember SET MemberStatusID = %s WHERE MemberID = %s",
                (MEMBER_STATUS_ACTIVE, member_id),
            )
            con.commit()

            org_name = _organization_name(cur, row["EventOrganizerID"])
            cur.execute(
                "SELECT CreatedByAccountID FROM eventorganizerinfo WHERE EventOrganizerID = %s",
                (row["EventOrganizerID"],),
            )
            owner_row = cur.fetchone()
            if owner_row:
                notify_accounts(
                    [owner_row["CreatedByAccountID"]],
                    "system",
                    "A team member joined",
                    f"A new member accepted the invitation to join '{org_name}'.",
                )

        return {"msg": "Invitation accepted", "MemberID": member_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def decline_organizermember(member_id: int, current=Depends(get_current_account)):
    """Decline a pending invitation. Only the invited account may decline."""
    try:
        con = getConnect()
        with con.cursor() as cur:
            row = _member_row(cur, member_id)
            if not row:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organizer member not found")
            if row["AccountID"] != current["account_id"]:
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="This invitation is not for you")
            if row["MemberStatusID"] != MEMBER_STATUS_PENDING:
                raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="This invitation is no longer pending")

            cur.execute(
                "UPDATE organizermember SET MemberStatusID = %s WHERE MemberID = %s",
                (MEMBER_STATUS_DECLINED, member_id),
            )
            con.commit()

            org_name = _organization_name(cur, row["EventOrganizerID"])
            cur.execute(
                "SELECT CreatedByAccountID FROM eventorganizerinfo WHERE EventOrganizerID = %s",
                (row["EventOrganizerID"],),
            )
            owner_row = cur.fetchone()
            if owner_row:
                notify_accounts(
                    [owner_row["CreatedByAccountID"]],
                    "system",
                    "An invitation was declined",
                    f"The invited member declined the invitation to join '{org_name}'.",
                )

        return {"msg": "Invitation declined", "MemberID": member_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def update_organizermember(req_data: UpdateOrganizerMemberRequest, current=Depends(require_permission("manage_event_members"))):
    try:
        con = getConnect()
        with con.cursor() as cur:
            # Confirm the row exists via SELECT rather than relying on
            # UPDATE rowcount, which is 0 for "matched but unchanged" rows
            # too and would otherwise falsely report "not found".
            cur.execute(
                "SELECT MemberID FROM organizermember WHERE MemberID = %s",
                (req_data.MemberID,),
            )
            if cur.fetchone() is None:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organizer member not found")

            # One organization per account, excluding this record itself.
            cur.execute(
                "SELECT MemberID FROM organizermember WHERE AccountID = %s AND MemberID != %s AND MemberStatusID != %s",
                (req_data.AccountID, req_data.MemberID, MEMBER_STATUS_REMOVED),
            )
            if cur.fetchone() is not None:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="This account already belongs to an organization",
                )

            if req_data.MemberStatusID is not None:
                sql = """
                    UPDATE organizermember
                    SET AccountID = %s,
                        EventOrganizerID = %s,
                        TeamRoleID = %s,
                        MemberStatusID = %s
                    WHERE MemberID = %s
                """
                cur.execute(sql, (
                    req_data.AccountID,
                    req_data.EventOrganizerID,
                    req_data.TeamRoleID,
                    req_data.MemberStatusID,
                    req_data.MemberID,
                ))
            else:
                sql = """
                    UPDATE organizermember
                    SET AccountID = %s,
                        EventOrganizerID = %s,
                        TeamRoleID = %s
                    WHERE MemberID = %s
                """
                cur.execute(sql, (
                    req_data.AccountID,
                    req_data.EventOrganizerID,
                    req_data.TeamRoleID,
                    req_data.MemberID,
                ))
            con.commit()

        return {"msg": "Organizer member updated successfully", "MemberID": req_data.MemberID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def delete_organizermember(member_id: int, current=Depends(get_current_account)):
    """
    Soft-delete: marks the membership row Removed instead of deleting it, so
    pending invitations can be revoked and active members can be kicked while
    preserving the row for audit and event staff assignments. Admin / Owner of
    the member's organization only; the organization creator is never removable.
    """
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute(
                "SELECT MemberID FROM organizermember WHERE MemberID = %s",
                (member_id,),
            )
            target = cur.fetchone()
            if target is None:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organizer member not found")

            cur.execute(
                "SELECT CreatedByAccountID FROM eventorganizerinfo WHERE EventOrganizerID = %s",
                (target["EventOrganizerID"],),
            )
            org_row = cur.fetchone()
            if org_row and org_row["CreatedByAccountID"] == target["AccountID"]:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="The organization owner cannot be removed",
                )

        await ensure_org_manager(con, current, target["EventOrganizerID"])

        with con.cursor() as cur:
            cur.execute(
                "UPDATE organizermember SET MemberStatusID = %s WHERE MemberID = %s",
                (MEMBER_STATUS_REMOVED, member_id),
            )
            con.commit()

        return {"msg": "Organizer member removed successfully", "MemberID": member_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


# ---------------------------------------------------------------------------
# Team member dashboard endpoints.
#
# These power the role-based "Team Member Dashboard" in the mobile app. Access
# is checked against the caller's active membership row via auth.team_access
# rather than the global RBAC permissions, so a CUSTOMER account invited as a
# volunteer/designer/admin can use the dashboard without any global role.
# ---------------------------------------------------------------------------

async def get_my_memberships(current=Depends(get_current_account)):
    """
    The caller's active organization memberships: the org they belong to, the
    team role they hold, and the org owner's account id (to avoid an extra
    round-trip when rendering the dashboard header).
    """
    try:
        con = getConnect()
        row = active_membership(con, current["account_id"])
        return [row] if row else []

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_my_team_member_events(current=Depends(get_current_account)):
    """
    Events of the caller's organization the caller may work on. Managers
    (Admin / Owner) see every event of the org; assigned volunteers and staff
    see their own events. Each event carries `assigned` so the app can hide
    check-in/attendee buttons for unassigned members and the full event row so
    designers can hand it straight to the event form.
    """
    try:
        con = getConnect()
        member = active_membership(con, current["account_id"])
        if member is None:
            return []

        org_id = member["EventOrganizerID"]
        owner_id = member["CreatedByAccountID"]
        role_id = member["TeamRoleID"]
        is_manager = member["AccountID"] == owner_id or role_id in (4, 5)

        with con.cursor() as cur:
            cur.execute(
                """
                SELECT e.EventID, e.EventName, e.EventStartingYMDT, e.EventEndingYMDT,
                       e.EventAddress, e.Latitude, e.Longitude, e.EventDescription,
                       e.EventOrganizerID, e.OnePerPerson, e.EventStatusID, e.EventVisible,
                       es.MemberID AS AssignedMemberID,
                       ev.RoleName AS EventRoleName
                FROM eventinfo e
                LEFT JOIN eventstaff es ON es.EventID = e.EventID AND es.MemberID = %s
                LEFT JOIN eventrole ev ON ev.EventRoleID = es.EventRoleID
                WHERE e.EventOrganizerID = %s
                ORDER BY e.EventStartingYMDT DESC
                """,
                (member["MemberID"], org_id),
            )
            rows = cur.fetchall()

        result = []
        for row in rows:
            assigned = is_manager or row["AssignedMemberID"] is not None
            result.append({
                "EventID": row["EventID"],
                "EventName": row["EventName"],
                "EventStartingYMDT": row["EventStartingYMDT"],
                "EventEndingYMDT": row["EventEndingYMDT"],
                "EventAddress": row["EventAddress"],
                "Latitude": row["Latitude"],
                "Longitude": row["Longitude"],
                "EventDescription": row["EventDescription"],
                "EventOrganizerID": row["EventOrganizerID"],
                "OnePerPerson": row["OnePerPerson"],
                "EventStatusID": row["EventStatusID"],
                "EventVisible": row["EventVisible"],
                "EventRoleName": row["EventRoleName"],
                "assigned": bool(assigned),
                "TeamRoleID": role_id,
            })
        return {"org": {
            "EventOrganizerID": org_id,
            "EventOrganizerName": member["EventOrganizerName"],
            "EventOrganizerLogoPath": member["EventOrganizerLogoPath"],
            "CreatedByAccountID": owner_id,
            "TeamRoleID": role_id,
            "TeamRoleName": member["TeamRoleName"],
        }, "events": result}

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_org_team(org_id: int, current=Depends(get_current_account)):
    """
    Full team roster for an organization: every membership row (including
    pending invites) enriched with the account, role, status, and the events
    each active member is assigned to. Admin / Owner only.
    """
    try:
        con = getConnect()
        await ensure_org_manager(con, current, org_id)

        with con.cursor() as cur:
            cur.execute(
                """
                SELECT om.MemberID, om.AccountID, om.EventOrganizerID, om.TeamRoleID,
                       om.MemberStatusID,
                       a.FirstName, a.LastName, a.Email,
                       tr.TeamRoleName, ms.StatusName, eo.CreatedByAccountID
                FROM organizermember om
                LEFT JOIN accountinfo a ON a.AccountID = om.AccountID
                LEFT JOIN teamrole tr ON tr.TeamRoleID = om.TeamRoleID
                LEFT JOIN memberstatusinfo ms ON ms.MemberStatusID = om.MemberStatusID
                LEFT JOIN eventorganizerinfo eo ON eo.EventOrganizerID = om.EventOrganizerID
                WHERE om.EventOrganizerID = %s
                ORDER BY om.MemberStatusID ASC, om.MemberID DESC
                """,
                (org_id,),
            )
            member_rows = cur.fetchall()

            cur.execute(
                """
                SELECT es.MemberID, es.EventID, e.EventName
                FROM eventstaff es
                JOIN eventinfo e ON e.EventID = es.EventID
                WHERE es.MemberID IN (
                    SELECT MemberID FROM organizermember WHERE EventOrganizerID = %s
                )
                ORDER BY es.EventID
                """,
                (org_id,),
            )
            assign_rows = cur.fetchall()

        assignments = {}
        for row in assign_rows:
            assignments.setdefault(row["MemberID"], []).append({
                "EventID": row["EventID"],
                "EventName": row["EventName"],
            })

        result = []
        for m in member_rows:
            result.append({
                "MemberID": m["MemberID"],
                "AccountID": m["AccountID"],
                "FirstName": m["FirstName"],
                "LastName": m["LastName"],
                "Email": m["Email"],
                "TeamRoleID": m["TeamRoleID"],
                "TeamRoleName": m["TeamRoleName"],
                "MemberStatusID": m["MemberStatusID"],
                "StatusName": m["StatusName"],
                "IsOwner": bool(m["CreatedByAccountID"] == m["AccountID"]),
                "AssignedEvents": assignments.get(m["MemberID"], []),
            })
        return result

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def change_member_role(req_data: ChangeMemberRoleRequest, current=Depends(get_current_account)):
    """
    Changes a member's team role. The Org Owner role cannot be granted here
    (use transfer ownership); the org creator cannot be demoted.
    """
    try:
        con = getConnect()
        with con.cursor() as cur:
            target = _member_row(cur, req_data.MemberID)
            if not target:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organizer member not found")

            await ensure_org_manager(con, current, target["EventOrganizerID"])

            if req_data.TeamRoleID == TEAM_ROLE_ORG_OWNER:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="The Org Owner role is granted by transferring ownership",
                )
            if not 1 <= req_data.TeamRoleID <= 4:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid team role")

            cur.execute(
                "SELECT CreatedByAccountID FROM eventorganizerinfo WHERE EventOrganizerID = %s",
                (target["EventOrganizerID"],),
            )
            owner_row = cur.fetchone()
            if owner_row and owner_row["CreatedByAccountID"] == target["AccountID"]:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="The organization owner's role cannot be changed",
                )

            cur.execute(
                "UPDATE organizermember SET TeamRoleID = %s WHERE MemberID = %s",
                (req_data.TeamRoleID, req_data.MemberID),
            )
            con.commit()

        return {"msg": "Team role updated", "MemberID": req_data.MemberID, "TeamRoleID": req_data.TeamRoleID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def transfer_org_ownership(req_data: TransferOwnershipRequest, current=Depends(get_current_account)):
    """
    Hands the organization to an active member: they become Org Owner, the
    current creator/admin keeps Admin (if they have a membership row), and
    eventorganizerinfo.CreatedByAccountID is updated so future access checks
    recognise the new owner.
    """
    try:
        con = getConnect()
        await ensure_org_owner(con, current, req_data.EventOrganizerID)

        with con.cursor() as cur:
            creator_row = _member_row(cur, req_data.NewOwnerMemberID)
            if not creator_row:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="New owner member not found")
            if creator_row["EventOrganizerID"] != req_data.EventOrganizerID:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="The new owner must belong to this organization")
            if creator_row["MemberStatusID"] != MEMBER_STATUS_ACTIVE:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="The new owner must have an active membership")
            if creator_row["AccountID"] == current["account_id"]:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="You already own this organization")

            cur.execute(
                "UPDATE organizermember SET TeamRoleID = %s WHERE MemberID = %s",
                (TEAM_ROLE_ORG_OWNER, req_data.NewOwnerMemberID),
            )

            cur.execute(
                "SELECT MemberID FROM organizermember WHERE AccountID = %s AND EventOrganizerID = %s",
                (current["account_id"], req_data.EventOrganizerID),
            )
            current_owner_row = cur.fetchone()
            if current_owner_row:
                cur.execute(
                    "UPDATE organizermember SET TeamRoleID = %s WHERE MemberID = %s",
                    (4, current_owner_row["MemberID"]),
                )

            cur.execute(
                "UPDATE eventorganizerinfo SET CreatedByAccountID = %s WHERE EventOrganizerID = %s",
                (creator_row["AccountID"], req_data.EventOrganizerID),
            )
            con.commit()

            cur.execute(
                "SELECT EventOrganizerName FROM eventorganizerinfo WHERE EventOrganizerID = %s",
                (req_data.EventOrganizerID,),
            )
            org_row = cur.fetchone()
            org_name = org_row["EventOrganizerName"] if org_row else "your organization"
            notify_accounts(
                [creator_row["AccountID"]],
                "system",
                "Organization ownership transferred",
                f"You are now the owner of '{org_name}'. You can manage the whole team and the organization.",
                link=f"org_invite:{req_data.NewOwnerMemberID}",
            )

        return {"msg": "Ownership transferred successfully", "NewOwnerMemberID": req_data.NewOwnerMemberID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def assign_member_to_event(req_data: AssignMemberEventRequest, current=Depends(get_current_account)):
    """
    Assigns an active member to an event so they can check in attendees there.
    Admin / Owner only.
    """
    try:
        con = getConnect()
        with con.cursor() as cur:
            target = _member_row(cur, req_data.MemberID)
            if not target:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organizer member not found")
            if target["MemberStatusID"] != MEMBER_STATUS_ACTIVE:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Only active members can be assigned")

            await ensure_org_manager(con, current, target["EventOrganizerID"])

            cur.execute(
                "SELECT EventID FROM eventinfo WHERE EventID = %s AND EventOrganizerID = %s",
                (req_data.EventID, target["EventOrganizerID"]),
            )
            if cur.fetchone() is None:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found in this organization")

            cur.execute(
                "SELECT AssigmentID FROM eventstaff WHERE EventID = %s AND MemberID = %s",
                (req_data.EventID, req_data.MemberID),
            )
            existing = cur.fetchone()
            if existing:
                return {"msg": "Member is already assigned to this event", "AssigmentID": existing["AssigmentID"]}

            cur.execute(
                "INSERT INTO eventstaff (EventID, MemberID, EventRoleID) VALUES (%s, %s, %s)",
                (req_data.EventID, req_data.MemberID, req_data.EventRoleID),
            )
            con.commit()
            assigment_id = cur.lastrowid

        return {"msg": "Member assigned to event", "AssigmentID": assigment_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def unassign_member_from_event(req_data: UnassignMemberEventRequest, current=Depends(get_current_account)):
    """
    Removes a member from an event. Admin / Owner only. Missing assignment is
    not an error so a UI that toggles "assigned" off can call this safely.
    """
    try:
        con = getConnect()
        with con.cursor() as cur:
            target = _member_row(cur, req_data.MemberID)
            if not target:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organizer member not found")

            await ensure_org_manager(con, current, target["EventOrganizerID"])

            cur.execute(
                "DELETE FROM eventstaff WHERE EventID = %s AND MemberID = %s",
                (req_data.EventID, req_data.MemberID),
            )
            con.commit()

        return {"msg": "Member unassigned from event", "MemberID": req_data.MemberID, "EventID": req_data.EventID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})