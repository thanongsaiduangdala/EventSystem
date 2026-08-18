import pymysql
from fastapi import HTTPException, status
from DB.DBConnect import getConnect
from models.schema import AddEventStaffRequest, UpdateEventStaffRequest


async def create_eventstaff(req_data: AddEventStaffRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            # Defense in depth: the picked member must belong to the same
            # organization that owns this event. The Flutter picker already
            # filters to this, but enforce it here too in case that's ever
            # bypassed (a different client, a stale UI, etc).
            #
            # ASSUMPTION: events table is named "event" -- verify this
            # against your actual EventInfo_controllers.py. Given your other
            # tables are "sponserinfo" / "eventorganizerInfo", it may
            # actually be "eventinfo". Fix the table name below if so.
            cur.execute("""
                SELECT ev.EventOrganizerID AS event_org, om.EventOrganizerID AS member_org
                FROM event ev, organizermember om
                WHERE ev.EventID = %s AND om.MemberID = %s
            """, (req_data.EventID, req_data.MemberID))
            match_row = cur.fetchone()
            if match_row is None:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event or member not found")
            event_org = match_row["event_org"] if isinstance(match_row, dict) else match_row[0]
            member_org = match_row["member_org"] if isinstance(match_row, dict) else match_row[1]
            if event_org != member_org:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="This member does not belong to the organization running this event",
                )

            # Block double-booking: the same underlying account (via its
            # organizermember record) can't be staff on the same event twice,
            # even under a different role or a different MemberID.
            cur.execute("""
                SELECT es.AssigmentID
                FROM eventstaff es
                INNER JOIN organizermember om ON om.MemberID = es.MemberID
                WHERE es.EventID = %s
                  AND om.AccountID = (
                      SELECT AccountID FROM organizermember WHERE MemberID = %s
                  )
            """, (req_data.EventID, req_data.MemberID))
            if cur.fetchone() is not None:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="This account is already assigned as staff for this event",
                )

            sql = """
                INSERT INTO eventstaff
                (EventID, MemberID, EventRoleID, AssignedAtYMDT)
                VALUES (%s, %s, %s, %s)
            """
            cur.execute(sql, (
                req_data.EventID,
                req_data.MemberID,
                req_data.EventRoleID,
                req_data.AssignedAtYMDT,
            ))
            con.commit()
            Assignment_ID = cur.lastrowid

        return {"msg": "Event staff created successfully", "AssignmentID": Assignment_ID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_all_EventStaff():
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM eventstaff"
            cur.execute(sql)
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_eventstaff_by_id(assignment_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM eventstaff WHERE AssigmentID = %s"
            cur.execute(sql, (assignment_id,))
            row = cur.fetchone()

        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event staff assignment not found")

        return row

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_eventstaff_by_event_id(event_id: int):
    """Convenience lookup: all staff assignments for a given EventID."""
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM eventstaff WHERE EventID = %s"
            cur.execute(sql, (event_id,))
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def update_eventstaff(req_data: UpdateEventStaffRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            # Confirm the row exists via SELECT rather than relying on
            # UPDATE rowcount -- rowcount is 0 for "matched but unchanged"
            # rows too (e.g. editing without actually changing any value),
            # which would otherwise falsely report "not found".
            cur.execute(
                "SELECT AssigmentID FROM eventstaff WHERE AssigmentID = %s",
                (req_data.AssignmentID,),
            )
            if cur.fetchone() is None:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event staff assignment not found")

            # Same org-match check as create -- see ASSUMPTION note there
            # about the events table name.
            cur.execute("""
                SELECT ev.EventOrganizerID AS event_org, om.EventOrganizerID AS member_org
                FROM event ev, organizermember om
                WHERE ev.EventID = %s AND om.MemberID = %s
            """, (req_data.EventID, req_data.MemberID))
            match_row = cur.fetchone()
            if match_row is None:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event or member not found")
            event_org = match_row["event_org"] if isinstance(match_row, dict) else match_row[0]
            member_org = match_row["member_org"] if isinstance(match_row, dict) else match_row[1]
            if event_org != member_org:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="This member does not belong to the organization running this event",
                )

            # Block double-booking, excluding this assignment itself so a
            # no-op edit (e.g. just changing the role) doesn't trip on its
            # own existing row.
            cur.execute("""
                SELECT es.AssigmentID
                FROM eventstaff es
                INNER JOIN organizermember om ON om.MemberID = es.MemberID
                WHERE es.EventID = %s
                  AND om.AccountID = (
                      SELECT AccountID FROM organizermember WHERE MemberID = %s
                  )
                  AND es.AssigmentID != %s
            """, (req_data.EventID, req_data.MemberID, req_data.AssignmentID))
            if cur.fetchone() is not None:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="This account is already assigned as staff for this event",
                )

            sql = """
                UPDATE eventstaff
                SET EventID = %s,
                    MemberID = %s,
                    EventRoleID = %s,
                    AssignedAtYMDT = %s
                WHERE AssigmentID = %s
            """
            cur.execute(sql, (
                req_data.EventID,
                req_data.MemberID,
                req_data.EventRoleID,
                req_data.AssignedAtYMDT,
                req_data.AssignmentID,
            ))
            con.commit()

        return {"msg": "Event staff updated successfully", "AssignmentID": req_data.AssignmentID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def delete_eventstaff(assignment_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "DELETE FROM eventstaff WHERE AssigmentID = %s"
            cur.execute(sql, (assignment_id,))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event staff assignment not found")

            con.commit()

        return {"msg": "Event staff deleted successfully", "AssignmentID": assignment_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})