import pymysql
from fastapi import HTTPException, status, Depends
from DB.DBConnect import getConnect
from models.schema import AddEventInfoRequest, UpdateEventInfoRequest
from auth.dependencies import require_permission

async def create_event(req_data: AddEventInfoRequest, current=Depends(require_permission("create_event"))):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                INSERT INTO eventinfo
                (EventName, EventStartingYMDT, EventEndingYMDT, EventAddress,
                 Latitude, Longitude, EventDescription, EventOrganizerID, OnePerPerson)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
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
            ))
            con.commit()
            event_id = cur.lastrowid

        return {"msg": "Event created successfully", "event_id": event_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_all_events(current=Depends(require_permission("view_events"))):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("""
                SELECT EventID, EventName, EventStartingYMDT, EventEndingYMDT,
                       EventAddress, Latitude, Longitude, EventDescription, EventOrganizerID,
                       OnePerPerson
                FROM eventinfo
            """)
            events = cur.fetchall()

        return {"events": events}

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_event_by_id(event_id: int, current=Depends(require_permission("view_events"))):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("""
                SELECT EventID, EventName, EventStartingYMDT, EventEndingYMDT,
                       EventAddress, Latitude, Longitude, EventDescription, EventOrganizerID,
                       OnePerPerson
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
    try:
        con = getConnect()
        with con.cursor() as cur:
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
                    OnePerPerson = %s
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
                req_data.EventID

            ))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

            con.commit()

        return {"msg": "Event updated successfully", "event_id": req_data.EventID}

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