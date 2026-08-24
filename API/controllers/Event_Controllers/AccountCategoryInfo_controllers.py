import pymysql
from fastapi import HTTPException, status
from DB.DBConnect import getConnect
from models.schema import SetAccountCategoriesRequest, AddAccountCategoryRequest


async def set_account_categories(req_data: SetAccountCategoriesRequest):
    """
    Replaces the account's full set of favorited categories in one call.
    Used both at signup (initial pick) and in the profile edit screen.
    """
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute(
                "DELETE FROM accountcategoryinfo WHERE AccountID = %s",
                (req_data.AccountID,),
            )

            if req_data.CategoryIDs:
                sql = """
                    INSERT INTO accountcategoryinfo (AccountID, CategoryID)
                    VALUES (%s, %s)
                """
                values = [(req_data.AccountID, cid) for cid in req_data.CategoryIDs]
                cur.executemany(sql, values)

            con.commit()

        return {
            "msg": "Account categories updated successfully",
            "AccountID": req_data.AccountID,
            "CategoryIDs": req_data.CategoryIDs,
        }

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def add_account_category(req_data: AddAccountCategoryRequest):
    """Favorite a single category -- used by the admin dashboard's create form."""
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                INSERT INTO accountcategoryinfo (AccountID, CategoryID)
                VALUES (%s, %s)
            """
            cur.execute(sql, (req_data.AccountID, req_data.CategoryID))
            con.commit()
            account_category_id = cur.lastrowid

        return {"msg": "Category favorited successfully", "AccountCategoryID": account_category_id}

    except HTTPException:
        raise
    except pymysql.err.IntegrityError:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Category already favorited by this account")
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_all_account_categories():
    """All account<->category favorites, joined with category names, for the admin dashboard table."""
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                SELECT ac.AccountCategoryID, ac.AccountID, ac.CategoryID, ac.CreatedAtYMDT,
                       c.CategoryName
                FROM accountcategoryinfo ac
                JOIN categoryinfo c ON c.CategoryID = ac.CategoryID
                ORDER BY ac.CreatedAtYMDT DESC
            """
            cur.execute(sql)
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_account_categories(account_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                SELECT c.CategoryID, c.CategoryName, c.CategoryIconPath
                FROM accountcategoryinfo ac
                JOIN categoryinfo c ON c.CategoryID = ac.CategoryID
                WHERE ac.AccountID = %s
            """
            cur.execute(sql, (account_id,))
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def delete_account_category(account_category_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute(
                "DELETE FROM accountcategoryinfo WHERE AccountCategoryID = %s",
                (account_category_id,),
            )
            rows_deleted = cur.rowcount
            con.commit()

        if rows_deleted == 0:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Favorite not found")

        return {"msg": "Favorite removed successfully", "AccountCategoryID": account_category_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_recommended_events_for_account(account_id: int):
    """
    Events belonging to any category this account has favorited.
    Empty result just means "no favorites yet" -- the app should hide
    the recommendation row in that case rather than showing an error.
    """
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                SELECT DISTINCT e.*
                FROM eventinfo e
                JOIN eventcategoryinfo ec ON ec.EventID = e.EventID
                JOIN accountcategoryinfo ac ON ac.CategoryID = ec.CategoryID
                WHERE ac.AccountID = %s
                ORDER BY e.EventStartingYMDT ASC
            """
            cur.execute(sql, (account_id,))
            rows = cur.fetchall()

        return {"events": rows}

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})
