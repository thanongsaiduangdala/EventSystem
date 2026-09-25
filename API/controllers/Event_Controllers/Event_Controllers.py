import pymysql
from fastapi import HTTPException, status, Depends
from DB.DBConnect import getConnect
from models.schema import (
    AddEventInfoRequest, UpdateEventInfoRequest, UpdateEventStatusRequest,
    UpdateEventVisibilityRequest,
)
from auth.dependencies import require_permission, ROLE_SUPERADMIN
from controllers.Event_Controllers.Notification_controllers import (
    notify_accounts, staff_account_ids
)

# EventStatusID values: 1 = Pending, 2 = Approved, 3 = Denied.
EVENT_STATUS_PENDING = 1
EVENT_STATUS_APPROVED = 2
EVENT_STATUS_DENIED = 3

EVENT_SELECT_COLUMNS = """
    EventID, EventName, EventStartingYMDT, EventEndingYMDT,
    EventAddress, Latitude, Longitude, EventDescription, EventOrganizerID,
    OnePerPerson, EventStatusID, EventVisible
"""


def _event_status_for(current) -> int:
    """New/edited events need approval. Only a SUPERADMIN creating directly
    gets an immediately-Approved event; everyone else starts as Pending."""
    return EVENT_STATUS_APPROVED if current.get("status_id") == ROLE_SUPERADMIN else EVENT_STATUS_PENDING


async def create_event(req_data: AddEventInfoRequest, current=Depends(require_permission("create_event"))):
    try:
        con = getConnect()
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
                _event_status_for(current),
            ))
            con.commit()
            event_id = cur.lastrowid

        notify_accounts(
            staff_account_ids(),
            "event",
            "New event awaiting approval",
            f"'{req_data.EventName}' has been submitted for approval.",
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


async def get_events_with_status(current=Depends(require_permission("create_event"))):
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

        return {"events": events}

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

        return {"event": event}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def update_event(req_data: UpdateEventInfoRequest, current=Depends(require_permission("update_event"))):
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


async def set_event_visibility(req_data: UpdateEventVisibilityRequest, current=Depends(require_permission("update_event"))):
    """Organizer action: show/hide an event from the public listing (e.g.
    sold out, postponed) without touching its approval status. Distinct from
    admin approval on purpose: approval is "is this content OK", visibility
    is "should it be listed right now", and organizers should control the
    latter without needing an admin at all."""
    try:
        con = getConnect()
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


async def update_event_status(req_data: UpdateEventStatusRequest, current=Depends(require_permission("update_event"))):
    """Admin/employee action: approve (2) or deny (3) a pending event."""
    if req_data.EventStatusID not in (EVENT_STATUS_PENDING, EVENT_STATUS_APPROVED, EVENT_STATUS_DENIED):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="EventStatusID must be 1 (pending), 2 (approved) or 3 (denied)",
        )

    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute(
                "UPDATE eventinfo SET EventStatusID = %s WHERE EventID = %s",
                (req_data.EventStatusID, req_data.EventID),
            )

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

            con.commit()

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

        if event_row is not None and event_row["OwnerAccountID"]:
            if req_data.EventStatusID == EVENT_STATUS_APPROVED:
                title, body = (
                    "Event approved",
                    f"Your event '{event_row['EventName']}' was approved and "
                    "is now visible to everyone.",
                )
            elif req_data.EventStatusID == EVENT_STATUS_DENIED:
                title, body = (
                    "Event not approved",
                    f"Your event '{event_row['EventName']}' was not approved. "
                    "Please review the details and resubmit.",
                )
            else:
                title, body = None, None

            if title is not None:
                notify_accounts(
                    [event_row["OwnerAccountID"]],
                    "event",
                    title,
                    body,
                )

        return {"msg": "Event status updated successfully", "event_id": req_data.EventID, "EventStatusID": req_data.EventStatusID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def delete_event(event_id: int, current=Depends(require_permission("delete_event"))):
    try:
        con = getConnect()
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