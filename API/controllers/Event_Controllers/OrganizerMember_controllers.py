from typing import Optional

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
    SetEventScanRequest,
    SetMemberScanRequest,
)
from auth.dependencies import require_permission, get_current_account
from auth.team_access import (
    TEAM_ROLE_ORG_OWNER,
    active_membership,
    active_memberships,
    sync_owner_memberships,
    ensure_org_manager,
    ensure_org_owner,
    event_org_id,
)
from controllers.Event_Controllers.Notification_controllers import notify_accounts

MEMBER_STATUS_PENDING = 1
MEMBER_STATUS_ACTIVE = 2
MEMBER_STATUS_DECLINED = 3
MEMBER_STATUS_REMOVED = 4


def _current_orgs(cur, account_id) -> list:
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
            cur.execute(
                "SELECT MemberID FROM organizermember "
                "WHERE AccountID = %s AND EventOrganizerID = %s AND MemberStatusID != %s",
                (req_data.AccountID, req_data.EventOrganizerID, MEMBER_STATUS_REMOVED),
            )
            if cur.fetchone() is not None:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="This account is already part of (or invited to) this organization",
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
            Member_ID = cur.lastrowid
            con.commit()

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
                "SELECT MemberID FROM organizermember "
                "WHERE AccountID = %s AND EventOrganizerID = %s AND MemberStatusID != %s",
                (account_id, req_data.EventOrganizerID, MEMBER_STATUS_REMOVED),
            )
            if cur.fetchone() is not None:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="This account is already part of (or invited to) this organization",
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
            member_id = cur.lastrowid
            con.commit()

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
            cur.execute(
                "SELECT MemberID FROM organizermember WHERE MemberID = %s",
                (req_data.MemberID,),
            )
            if cur.fetchone() is None:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organizer member not found")

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
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute(
                "SELECT MemberID, AccountID, EventOrganizerID FROM organizermember WHERE MemberID = %s",
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


async def get_my_memberships(current=Depends(get_current_account)):
    try:
        con = getConnect()
        sync_owner_memberships(con, current["account_id"])
        return active_memberships(con, current["account_id"])

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_my_invites(current=Depends(get_current_account)):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute(
                """
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
                WHERE om.AccountID = %s AND om.MemberStatusID = %s
                  AND eo.OrganizerStatusID = 2
                ORDER BY om.MemberID DESC
                """,
                (current["account_id"], MEMBER_STATUS_PENDING),
            )
            return cur.fetchall()

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_my_team_member_events(org_id: Optional[int] = None, current=Depends(get_current_account)):
    try:
        con = getConnect()
        sync_owner_memberships(con, current["account_id"])
        member = active_membership(con, current["account_id"], org_id)
        if member is None:
            return {"org": None, "events": []}

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
                       es.MemberID AS AssignedMemberID, es.CanScan, e.ScanEnabled,
                       ev.RoleName AS EventRoleName
                FROM eventinfo e
                LEFT JOIN eventstaff es ON es.EventID = e.EventID AND es.MemberID = %s
                LEFT JOIN eventrole ev ON ev.EventRoleID = es.EventRoleID
                WHERE e.EventOrganizerID = %s
                """ + ("" if is_manager else " AND es.MemberID IS NOT NULL ") + """
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
                "ScanAllowed": bool(is_manager or (assigned and (row["ScanEnabled"] or row["CanScan"]))),
                "TeamRoleID": role_id,
            })
        return {"org": {
            "MemberID": member["MemberID"],
            "AccountID": member["AccountID"],
            "MemberStatusID": member["MemberStatusID"],
            "EventOrganizerDiscription": member["EventOrganizerDiscription"],
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
            if target["MemberStatusID"] not in (MEMBER_STATUS_PENDING, MEMBER_STATUS_ACTIVE):
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Only active or pending members can change role")

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
    try:
        con = getConnect()
        with con.cursor() as cur:
            target = _member_row(cur, req_data.MemberID)
            if not target:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Organizer member not found")
            if target["MemberStatusID"] not in (MEMBER_STATUS_PENDING, MEMBER_STATUS_ACTIVE):
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Only active or pending members can be assigned")

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
                ("INSERT INTO eventstaff (EventID, MemberID, EventRoleID, AssignedAtYMDT) "
                "VALUES (%s, %s, %s, CURRENT_TIMESTAMP)"),
                (req_data.EventID, req_data.MemberID, req_data.EventRoleID),
            )
            assigment_id = cur.lastrowid
            con.commit()

        return {"msg": "Member assigned to event", "AssigmentID": assigment_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def unassign_member_from_event(req_data: UnassignMemberEventRequest, current=Depends(get_current_account)):
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


async def get_event_scan_access(event_id: int, current=Depends(get_current_account)):
    try:
        con = getConnect()
        org_id = event_org_id(con, event_id)
        if org_id is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
        await ensure_org_manager(con, current, org_id)

        with con.cursor() as cur:
            cur.execute("SELECT ScanEnabled FROM eventinfo WHERE EventID = %s", (event_id,))
            event_row = cur.fetchone()
            cur.execute(
                """
                SELECT om.MemberID, om.TeamRoleID, tr.TeamRoleName, es.CanScan,
                       a.FirstName, a.LastName
                FROM eventstaff es
                JOIN organizermember om ON om.MemberID = es.MemberID
                LEFT JOIN accountinfo a ON a.AccountID = om.AccountID
                LEFT JOIN teamrole tr ON tr.TeamRoleID = om.TeamRoleID
                WHERE es.EventID = %s AND om.MemberStatusID = %s AND om.TeamRoleID IN (1, 2)
                ORDER BY om.TeamRoleID, a.FirstName
                """,
                (event_id, MEMBER_STATUS_ACTIVE),
            )
            rows = cur.fetchall()

        return {
            "EventID": event_id,
            "ScanEnabled": bool(event_row["ScanEnabled"]),
            "Members": [
                {
                    "MemberID": r["MemberID"],
                    "FirstName": r["FirstName"],
                    "LastName": r["LastName"],
                    "TeamRoleID": r["TeamRoleID"],
                    "TeamRoleName": r["TeamRoleName"],
                    "CanScan": bool(r["CanScan"]),
                }
                for r in rows
            ],
        }

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def set_event_scan_enabled(req_data: SetEventScanRequest, current=Depends(get_current_account)):
    try:
        con = getConnect()
        org_id = event_org_id(con, req_data.EventID)
        if org_id is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
        await ensure_org_manager(con, current, org_id)

        with con.cursor() as cur:
            cur.execute(
                "UPDATE eventinfo SET ScanEnabled = %s WHERE EventID = %s",
                (1 if req_data.Enabled else 0, req_data.EventID),
            )
            con.commit()

        return {"msg": "Scanning updated", "EventID": req_data.EventID, "ScanEnabled": req_data.Enabled}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def set_member_scan_access(req_data: SetMemberScanRequest, current=Depends(get_current_account)):
    try:
        con = getConnect()
        org_id = event_org_id(con, req_data.EventID)
        if org_id is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
        await ensure_org_manager(con, current, org_id)

        with con.cursor() as cur:
            cur.execute(
                "SELECT AssigmentID FROM eventstaff WHERE EventID = %s AND MemberID = %s",
                (req_data.EventID, req_data.MemberID),
            )
            if cur.fetchone() is None:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="This member is not assigned to the event")
            cur.execute(
                "UPDATE eventstaff SET CanScan = %s WHERE EventID = %s AND MemberID = %s",
                (1 if req_data.CanScan else 0, req_data.EventID, req_data.MemberID),
            )
            con.commit()

        return {"msg": "Member scan access updated", "MemberID": req_data.MemberID, "CanScan": req_data.CanScan}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})
