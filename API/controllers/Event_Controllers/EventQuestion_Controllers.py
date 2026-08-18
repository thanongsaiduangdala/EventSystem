import json

import pymysql
from fastapi import HTTPException, status, Depends
from DB.DBConnect import getConnect
from models.schema import (
    AddEventQuestionInfo,
    UpdateEventQuestionInfo,
    AddEventQuestionType,
    UpdateEventQuestionType,
)
from auth.dependencies import require_developer

# ---------------------------------------------------------------------------
# eventquestioninfo.Options is stored as a JSON-encoded text column (a list
# of option strings for choice-type questions, e.g. radio/checkbox/dropdown).
# It's optional -- free-text questions just leave it NULL.
# ---------------------------------------------------------------------------


def _serialize_options(options):
    return json.dumps(options) if options is not None else None


def _deserialize_row(row):
    """Turns the stored Options JSON text back into a list for the response.
    Leaves the row untouched if Options is NULL or already malformed JSON."""
    if row is None:
        return row
    options = row.get("Options") if isinstance(row, dict) else None
    if options:
        try:
            row["Options"] = json.loads(options)
        except (TypeError, ValueError):
            pass
    return row


# ---------------- eventquestioninfo ----------------


async def create_event(req_data: AddEventQuestionInfo, current=Depends(require_developer)):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                INSERT INTO eventquestioninfo
                (EventID, EventQuestion, EventQuestionTypeID, IsRequire, SortOrder, Options)
                VALUES (%s, %s, %s, %s, %s, %s)
            """
            cur.execute(sql, (
                req_data.EventID,
                req_data.EventQuestion,
                req_data.EventQuestionTypeID,
                req_data.IsRequire,
                req_data.SortOrder,
                _serialize_options(req_data.Options),
            ))
            con.commit()
            eventquestion_id = cur.lastrowid

        return {"msg": "Event question created successfully", "EventQuestionID": eventquestion_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_all_events(current=Depends(require_developer)):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("""
                SELECT EventQuestionID, EventID, EventQuestion, EventQuestionTypeID,
                       IsRequire, SortOrder, Options
                FROM eventquestioninfo
                ORDER BY EventID, SortOrder
            """)
            rows = cur.fetchall()

        return {"eventquestions": [_deserialize_row(r) for r in rows]}

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_event_by_id(eventquestion_id: int, current=Depends(require_developer)):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("""
                SELECT EventQuestionID, EventID, EventQuestion, EventQuestionTypeID,
                       IsRequire, SortOrder, Options
                FROM eventquestioninfo
                WHERE EventQuestionID = %s
            """, (eventquestion_id,))
            row = cur.fetchone()

        if row is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event question not found")

        return {"eventquestion": _deserialize_row(row)}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_eventquestions_by_event_id(event_id: int, current=Depends(require_developer)):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("""
                SELECT EventQuestionID, EventID, EventQuestion, EventQuestionTypeID,
                       IsRequire, SortOrder, Options
                FROM eventquestioninfo
                WHERE EventID = %s
                ORDER BY SortOrder
            """, (event_id,))
            rows = cur.fetchall()

        return {"eventquestions": [_deserialize_row(r) for r in rows]}

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def update_event(req_data: UpdateEventQuestionInfo, current=Depends(require_developer)):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                UPDATE eventquestioninfo
                SET EventID = %s,
                    EventQuestion = %s,
                    EventQuestionTypeID = %s,
                    IsRequire = %s,
                    SortOrder = %s,
                    Options = %s
                WHERE EventQuestionID = %s
            """
            cur.execute(sql, (
                req_data.EventID,
                req_data.EventQuestion,
                req_data.EventQuestionTypeID,
                req_data.IsRequire,
                req_data.SortOrder,
                _serialize_options(req_data.Options),
                req_data.EventQuestionID,
            ))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event question not found")

            con.commit()

        return {"msg": "Event question updated successfully", "EventQuestionID": req_data.EventQuestionID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def delete_event(eventquestion_id: int, current=Depends(require_developer)):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("DELETE FROM eventquestioninfo WHERE EventQuestionID = %s", (eventquestion_id,))
            rows_deleted = cur.rowcount
            con.commit()

        if rows_deleted == 0:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event question not found")

        return {"msg": "Event question deleted successfully", "EventQuestionID": eventquestion_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


# ---------------- eventquestiontype ----------------


async def create_eventquestiontype(req_data: AddEventQuestionType, current=Depends(require_developer)):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "INSERT INTO eventquestiontype (EventQuestionType) VALUES (%s)"
            cur.execute(sql, (req_data.EventQuestionType,))
            con.commit()
            eventquestiontype_id = cur.lastrowid

        return {"msg": "Event question type created successfully", "EventQuestionTypeID": eventquestiontype_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_all_eventquestiontypes(current=Depends(require_developer)):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("SELECT EventQuestionTypeID, EventQuestionType FROM eventquestiontype")
            rows = cur.fetchall()

        return {"eventquestiontypes": rows}

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_eventquestiontype_by_id(eventquestiontype_id: int, current=Depends(require_developer)):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute(
                "SELECT EventQuestionTypeID, EventQuestionType FROM eventquestiontype WHERE EventQuestionTypeID = %s",
                (eventquestiontype_id,),
            )
            row = cur.fetchone()

        if row is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event question type not found")

        return {"eventquestiontype": row}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def update_eventquestiontype(req_data: UpdateEventQuestionType, current=Depends(require_developer)):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "UPDATE eventquestiontype SET EventQuestionType = %s WHERE EventQuestionTypeID = %s"
            cur.execute(sql, (req_data.EventQuestionType, req_data.EventQuestionTypeID))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event question type not found")

            con.commit()

        return {"msg": "Event question type updated successfully", "EventQuestionTypeID": req_data.EventQuestionTypeID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def delete_eventquestiontype(eventquestiontype_id: int, current=Depends(require_developer)):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("DELETE FROM eventquestiontype WHERE EventQuestionTypeID = %s", (eventquestiontype_id,))
            rows_deleted = cur.rowcount
            con.commit()

        if rows_deleted == 0:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event question type not found")

        return {"msg": "Event question type deleted successfully", "EventQuestionTypeID": eventquestiontype_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})
