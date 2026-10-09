import pymysql
from fastapi import HTTPException, status, Depends
from DB.DBConnect import getConnect
from models.schema import (
    AddEventInfoRequest, UpdateEventInfoRequest, UpdateEventStatusRequest,
    UpdateEventVisibilityRequest,
)
from auth.dependencies import (
    require_permission, require_reviewer_or_permission, ROLE_SUPERADMIN, get_current_account,
)
from auth.team_access import (
    ensure_event_editor, ensure_org_editor, effective_role_for, is_manager, is_editor,
)
from controllers.Event_Controllers.Notification_controllers import (
    notify_accounts, staff_account_ids
)
from realtime.review_events import publish_review_change

# EventStatusID values: 1 = Pending, 2 = Approved, 3 = Denied, 4 = Draft.
# A Draft is saved on the server (photos included) but is private to the
# organization's owner/admins/editors until it is submitted for approval.
EVENT_STATUS_PENDING = 1
EVENT_STATUS_APPROVED = 2
EVENT_STATUS_DENIED = 3
EVENT_STATUS_DRAFT = 4

EVENT_SELECT_COLUMNS = """
    EventID, EventName, EventStartingYMDT, EventEndingYMDT,
    EventAddress, Latitude, Longitude, EventDescription, EventOrganizerID,
    OnePerPerson, EventStatusID, EventVisible, DenyReason
"""

MAX_DENY_REASON_LENGTH = 1000


def _owner_of_organizer(con, organizer_id):
    """AccountID of the organization's owner (None if unknown)."""
    with con.cursor() as cur:
        cur.execute(
            "SELECT CreatedByAccountID FROM eventorganizerinfo WHERE EventOrganizerID = %s",
            (organizer_id,),
        )
        row = cur.fetchone()
    return row["CreatedByAccountID"] if row else None


def _event_status_for(current) -> int:
    """New/edited events need approval. Only a SUPERADMIN creating directly
    gets an immediately-Approved event; everyone else starts as Pending."""
    return EVENT_STATUS_APPROVED if current.get("status_id") == ROLE_SUPERADMIN else EVENT_STATUS_PENDING


def _can_view_drafts(con, current, org_id) -> bool:
    """Drafts are visible to SUPERADMINs and to the organization's own
    owner / admins / page editors -- nobody else."""
    if current.get("status_id") == ROLE_SUPERADMIN:
        return True
    roles = effective_role_for(con, current["account_id"], org_id)
    return is_manager(roles) or is_editor(roles)


async def create_event(req_data: AddEventInfoRequest, current=Depends(get_current_account)):
    try:
        con = getConnect()
        await ensure_org_editor(con, current, req_data.EventOrganizerID, "create_event")
        with con.cursor() as cur:
            sql = """
                INSERT INTO eventinfo
                (EventName, EventStartingYMDT, EventEndingYMDT, EventAddress,
                 Latitude, Longitude, EventDescription, EventOrganizerID, OnePerPerson, EventStatusID)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """
            cur.execute(sql, (
                req_data.EventName,
                req_data.EventStartingYMDT,
                req_data.EventEndingYMDT,
                req_data.EventAddress,
                req_data.Latitude,
                req_data.Longitude,
                req_data.EventDescription,
                req_data.EventOrganizerID,
                1 if req_data.OnePerPerson else 0,
                EVENT_STATUS_DRAFT if req_data.AsDraft else _event_status_for(current),
            ))
            event_id = cur.lastrowid
            con.commit()

        if req_data.AsDraft:
            # Drafts are private: no one is asked to review it yet.
            return {"msg": "Draft saved successfully", "event_id": event_id,
                    "EventStatusID": EVENT_STATUS_DRAFT}

        notify_accounts(
            staff_account_ids(),
            "event",
            "New event awaiting approval",
            f"'{req_data.EventName}' has been submitted for approval.",
            link=f"event_review:{event_id}",
        )
        await publish_review_change(
            kind="event", item_id=event_id, status_id=_event_status_for(current),
            owner_account_id=_owner_of_organizer(con, req_data.EventOrganizerID),
        )

        return {"msg": "Event created successfully", "event_id": event_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_all_events(current=Depends(require_permission("view_events"))):
    """Public event list: only events that are both Approved (an admin
    checked the content) and Visible (the organizer wants it listed right
    now) show up here."""
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute(f"""
                SELECT {EVENT_SELECT_COLUMNS}
                FROM eventinfo
                WHERE EventStatusID = %s AND EventVisible = 1
                ORDER BY EventStartingYMDT
            """, (EVENT_STATUS_APPROVED,))
            events = cur.fetchall()

        return {"events": events}

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_events_with_status(current=Depends(require_reviewer_or_permission("create_event"))):
    """Management view: every event including Pending/Denied ones, so
    organizers can track approval and admins can review submissions."""
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute(f"""
                SELECT {EVENT_SELECT_COLUMNS}
                FROM eventinfo
                ORDER BY EventStatusID, EventStartingYMDT
            """)
            events = cur.fetchall()

        # Hide other organizations' drafts.
        allowed = {}
        visible = []
        for ev in events:
            if ev["EventStatusID"] == EVENT_STATUS_DRAFT:
                org = ev["EventOrganizerID"]
                if org not in allowed:
                    allowed[org] = _can_view_drafts(con, current, org)
                if not allowed[org]:
                    continue
            visible.append(ev)

        return {"events": visible}

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_event_by_id(event_id: int, current=Depends(require_permission("view_events"))):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute(f"""
                SELECT {EVENT_SELECT_COLUMNS}
                FROM eventinfo
                WHERE EventID = %s
            """, (event_id,))
            event = cur.fetchone()

        if event is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        if event["EventStatusID"] == EVENT_STATUS_DRAFT and not _can_view_drafts(
            con, current, event["EventOrganizerID"]
        ):
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        return {"event": event}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def update_event(req_data: UpdateEventInfoRequest, current=Depends(get_current_account)):
    """Editing an event does NOT require a fresh admin review by itself --
    that would make events flicker in and out of public view for routine
    edits (a typo fix, a time change), and it's especially bad right before
    an event if the admin is slow to re-review. Approved stays Approved and
    Pending stays Pending through an edit.

    The one exception is an event that was previously Denied: editing it is
    effectively a resubmission, so it goes back to Pending for another look.
    That reset is expressed as a CASE in the UPDATE itself so the "what was
    it before" check and the write happen atomically.
    """
    try:
        con = getConnect()
        await ensure_event_editor(con, current, req_data.EventID, "update_event")
        with con.cursor() as cur:
            # Needed both to know whether this is a resubmission (for the
            # notification) and to give a clean 404 if the event is gone.
            cur.execute("SELECT EventStatusID FROM eventinfo WHERE EventID = %s", (req_data.EventID,))
            existing = cur.fetchone()
            if existing is None:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

            was_denied = existing["EventStatusID"] == EVENT_STATUS_DENIED

            sql = """
                UPDATE eventinfo
                SET EventName = %s,
                    EventStartingYMDT = %s,
                    EventEndingYMDT = %s,
                    EventAddress = %s,
                    Latitude = %s,
                    Longitude = %s,
                    EventDescription = %s,
                    EventOrganizerID = %s,
                    OnePerPerson = %s,
                    -- Must come BEFORE the EventStatusID line: MySQL applies
                    -- SET assignments left to right, so by the time the status
                    -- changes below this CASE has already seen the old value.
                    DenyReason = CASE WHEN EventStatusID = %s THEN NULL ELSE DenyReason END,
                    EventStatusID = CASE WHEN EventStatusID = %s THEN %s ELSE EventStatusID END
                WHERE EventID = %s
            """
            cur.execute(sql, (
                req_data.EventName,
                req_data.EventStartingYMDT,
                req_data.EventEndingYMDT,
                req_data.EventAddress,
                req_data.Latitude,
                req_data.Longitude,
                req_data.EventDescription,
                req_data.EventOrganizerID,
                1 if req_data.OnePerPerson else 0,
                EVENT_STATUS_DENIED,
                EVENT_STATUS_DENIED,
                EVENT_STATUS_PENDING,
                req_data.EventID,
            ))
            con.commit()

            new_status = EVENT_STATUS_PENDING if was_denied else existing["EventStatusID"]

        if was_denied:
            notify_accounts(
                staff_account_ids(),
                "event",
                "Edited event resubmitted for approval",
                f"'{req_data.EventName}' was previously denied. It has been "
                "edited and is now pending approval again.",
                link=f"event_review:{req_data.EventID}",
            )
            await publish_review_change(
                kind="event", item_id=req_data.EventID, status_id=EVENT_STATUS_PENDING,
                owner_account_id=_owner_of_organizer(con, req_data.EventOrganizerID),
            )

        return {
            "msg": "Event updated successfully",
            "event_id": req_data.EventID,
            "EventStatusID": new_status,
        }

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def set_event_visibility(req_data: UpdateEventVisibilityRequest, current=Depends(get_current_account)):
    """Organizer action: show/hide an event from the public listing (e.g.
    sold out, postponed) without touching its approval status. Distinct from
    admin approval on purpose: approval is "is this content OK", visibility
    is "should it be listed right now", and organizers should control the
    latter without needing an admin at all."""
    try:
        con = getConnect()
        await ensure_event_editor(con, current, req_data.EventID, "update_event")
        with con.cursor() as cur:
            cur.execute(
                "UPDATE eventinfo SET EventVisible = %s WHERE EventID = %s",
                (1 if req_data.EventVisible else 0, req_data.EventID),
            )

            if cur.rowcount == 0:
                # rowcount is 0 both when nothing matched EventID and when
                # the value was already what was requested, so disambiguate
                # with a lookup before treating it as "not found".
                cur.execute("SELECT EventID FROM eventinfo WHERE EventID = %s", (req_data.EventID,))
                if cur.fetchone() is None:
                    con.rollback()
                    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

            con.commit()

        return {
            "msg": "Event visibility updated successfully",
            "event_id": req_data.EventID,
            "EventVisible": req_data.EventVisible,
        }

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def update_event_status(req_data: UpdateEventStatusRequest, current=Depends(require_reviewer_or_permission("update_event"))):
    """Admin/employee action: approve (2) or deny (3) a PENDING event.

    Two reviewers can have the same event open. The decision is written with
    `WHERE EventStatusID = Pending`, so only the first one wins; the second
    gets a 409 telling them it was already decided instead of silently
    overwriting the first reviewer's decision. A denial must carry a reason,
    which the organizer sees on their dashboard.
    """
    if req_data.EventStatusID not in (EVENT_STATUS_APPROVED, EVENT_STATUS_DENIED):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="EventStatusID must be 2 (approved) or 3 (denied)",
        )

    denying = req_data.EventStatusID == EVENT_STATUS_DENIED
    reason = (req_data.Reason or "").strip()
    if denying:
        if not reason:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Please give a reason when denying an event.",
            )
        if len(reason) > MAX_DENY_REASON_LENGTH:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"The reason is too long (max {MAX_DENY_REASON_LENGTH} characters).",
            )

    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute(
                "UPDATE eventinfo SET EventStatusID = %s, DenyReason = %s "
                "WHERE EventID = %s AND EventStatusID = %s",
                (
                    req_data.EventStatusID,
                    reason if denying else None,
                    req_data.EventID,
                    EVENT_STATUS_PENDING,
                ),
            )
            changed = cur.rowcount
            con.commit()

            if changed == 0:
                # Lost the race, wrong state, or no such event: say which.
                cur.execute("SELECT EventStatusID FROM eventinfo WHERE EventID = %s", (req_data.EventID,))
                row = cur.fetchone()
                if row is None:
                    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
                if row["EventStatusID"] == EVENT_STATUS_DRAFT:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="This event is still a draft. The organizer has not submitted it for approval yet.",
                    )
                decided = {
                    EVENT_STATUS_APPROVED: "approved",
                    EVENT_STATUS_DENIED: "denied",
                }.get(row["EventStatusID"], "reviewed")
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"This event was already {decided} by another reviewer. "
                           "The list has been refreshed.",
                )

            cur.execute(
                """
                SELECT e.EventName, eo.CreatedByAccountID AS OwnerAccountID
                FROM eventinfo e
                JOIN eventorganizerinfo eo ON eo.EventOrganizerID = e.EventOrganizerID
                WHERE e.EventID = %s
                """,
                (req_data.EventID,),
            )
            event_row = cur.fetchone()

        owner_id = event_row["OwnerAccountID"] if event_row else None
        if event_row is not None and owner_id:
            if not denying:
                title, body = (
                    "Event approved",
                    f"Your event '{event_row['EventName']}' was approved and "
                    "is now visible to everyone.",
                )
            else:
                title, body = (
                    "Event not approved",
                    f"Your event '{event_row['EventName']}' was not approved.\n"
                    f"Reason: {reason}\n"
                    "Please fix it, then open the event and press Save to "
                    "send it for review again.",
                )
            notify_accounts(
                [owner_id],
                "event",
                title,
                body,
                link=f"event:{req_data.EventID}",
            )

        await publish_review_change(
            kind="event",
            item_id=req_data.EventID,
            status_id=req_data.EventStatusID,
            owner_account_id=owner_id,
            deny_reason=reason if denying else None,
        )

        return {"msg": "Event status updated successfully", "event_id": req_data.EventID, "EventStatusID": req_data.EventStatusID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def delete_event(event_id: int, current=Depends(get_current_account)):
    try:
        con = getConnect()
        await ensure_event_editor(con, current, event_id, "delete_event", delete=True)
        with con.cursor() as cur:
            cur.execute("DELETE FROM eventinfo WHERE EventID = %s", (event_id,))
            rows_deleted = cur.rowcount
            con.commit()

        if rows_deleted == 0:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        return {"msg": "Event deleted successfully", "event_id": event_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def submit_event_draft(event_id: int, current=Depends(get_current_account)):
    """Turns a saved Draft into a real submission: Pending for review (or
    Approved straight away for a SUPERADMIN), and tells the reviewers."""
    try:
        con = getConnect()
        await ensure_event_editor(con, current, event_id, "create_event")
        with con.cursor() as cur:
            cur.execute(
                "SELECT EventName, EventStatusID FROM eventinfo WHERE EventID = %s",
                (event_id,),
            )
            row = cur.fetchone()
            if row is None:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
            if row["EventStatusID"] != EVENT_STATUS_DRAFT:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Only a draft can be submitted.",
                )
            new_status = _event_status_for(current)
            cur.execute(
                "UPDATE eventinfo SET EventStatusID = %s WHERE EventID = %s",
                (new_status, event_id),
            )
            con.commit()

        notify_accounts(
            staff_account_ids(),
            "event",
            "New event awaiting approval",
            f"'{row['EventName']}' has been submitted for approval.",
            link=f"event_review:{event_id}",
        )
        await publish_review_change(kind="event", item_id=event_id, status_id=new_status)
        return {"msg": "Event submitted successfully", "event_id": event_id, "EventStatusID": new_status}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})
