import pymysql
from fastapi import HTTPException, status
from DB.DBConnect import getConnect
from models.schema import AddCategoryInfoRequest, UpdateCategoryInfoRequest


async def create_category(req_data: AddCategoryInfoRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                INSERT INTO categoryinfo
                (CategoryName, CategoryIconPath)
                VALUES (%s, %s)
            """
            cur.execute(sql, (
                req_data.CategoryName,
                req_data.CategoryIconPath
            ))
            con.commit()
            Category_ID = cur.lastrowid

        return {"msg": "Category created successfully", "CategoryID": Category_ID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_all_Categories():
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM categoryinfo"
            cur.execute(sql)
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_category_by_id(category_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM categoryinfo WHERE CategoryID = %s"
            cur.execute(sql, (category_id,))
            row = cur.fetchone()

        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category not found")

        return row

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def update_category(req_data: UpdateCategoryInfoRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                UPDATE categoryinfo
                SET CategoryName = %s,
                    CategoryIconPath = %s
                WHERE CategoryID = %s
            """
            cur.execute(sql, (
                req_data.CategoryName,
                req_data.CategoryIconPath,
                req_data.CategoryID,
            ))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category not found")

            con.commit()

        return {"msg": "Category updated successfully", "CategoryID": req_data.CategoryID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def delete_category(category_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "DELETE FROM categoryinfo WHERE CategoryID = %s"
            cur.execute(sql, (category_id,))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category not found")

            con.commit()

        return {"msg": "Category deleted successfully", "CategoryID": category_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})