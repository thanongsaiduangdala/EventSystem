import pymysql
from fastapi import HTTPException, status
from DB.DBConnect import getConnect
from models.schema import AddEventCategoryInfoRequest, UpdateEventCategoryInfoRequest


async def create_eventcategory(req_data: AddEventCategoryInfoRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                INSERT INTO eventcategoryinfo
                (EventID, CategoryID)
                VALUES (%s, %s)
            """
            cur.execute(sql, (
                req_data.EventID,
                req_data.CategoryID
            ))
            con.commit()
            EventCategory_ID = cur.lastrowid

        return {"msg": "Event category created successfully", "EventCategoryID": EventCategory_ID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_all_EventCategories():
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM eventcategoryinfo"
            cur.execute(sql)
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_eventcategory_by_id(event_category_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM eventcategoryinfo WHERE EventCategoryID = %s"
            cur.execute(sql, (event_category_id,))
            row = cur.fetchone()

        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event category not found")

        return row

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_categories_by_event_id(event_id: int):
    """Convenience lookup: all category links for a given EventID."""
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM eventcategoryinfo WHERE EventID = %s"
            cur.execute(sql, (event_id,))
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def update_eventcategory(req_data: UpdateEventCategoryInfoRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                UPDATE eventcategoryinfo
                SET EventID = %s,
                    CategoryID = %s
                WHERE EventCategoryID = %s
            """
            cur.execute(sql, (
                req_data.EventID,
                req_data.CategoryID,
                req_data.EventCategoryID,
            ))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event category not found")

            con.commit()

        return {"msg": "Event category updated successfully", "EventCategoryID": req_data.EventCategoryID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def delete_eventcategory(event_category_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "DELETE FROM eventcategoryinfo WHERE EventCategoryID = %s"
            cur.execute(sql, (event_category_id,))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event category not found")

            con.commit()

        return {"msg": "Event category deleted successfully", "EventCategoryID": event_category_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})