import pymysql
from fastapi import HTTPException, status
from DB.DBConnect import getConnect
from models.schema import AddOrdersInfoRequest, UpdateOrdersInfoRequest


async def create_order(req_data: AddOrdersInfoRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                INSERT INTO ordersinfo
                (AccountID, PaymentTypeID, PaymentDateYMDT, ProveOfPayment)
                VALUES (%s, %s, %s, %s)
            """
            cur.execute(sql, (
                req_data.AccountID,
                req_data.PaymentTypeID,
                req_data.PaymentDateYMDT,
                req_data.ProveOfPayment,
            ))
            con.commit()
            Order_ID = cur.lastrowid

        return {"msg": "Order created successfully", "OrderID": Order_ID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_all_Orders():
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM ordersinfo"
            cur.execute(sql)
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_order_by_id(order_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM ordersinfo WHERE OrderID = %s"
            cur.execute(sql, (order_id,))
            row = cur.fetchone()

        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")

        return row

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_orders_by_account_id(account_id: int):
    """Convenience lookup: all orders placed by a given AccountID."""
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "SELECT * FROM ordersinfo WHERE AccountID = %s"
            cur.execute(sql, (account_id,))
            rows = cur.fetchall()

        return rows

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def update_order(req_data: UpdateOrdersInfoRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                UPDATE ordersinfo
                SET AccountID = %s,
                    PaymentTypeID = %s,
                    PaymentDateYMDT = %s,
                    ProveOfPayment = %s
                WHERE OrderID = %s
            """
            cur.execute(sql, (
                req_data.AccountID,
                req_data.PaymentTypeID,
                req_data.PaymentDateYMDT,
                req_data.ProveOfPayment,
                req_data.OrderID,
            ))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")

            con.commit()

        return {"msg": "Order updated successfully", "OrderID": req_data.OrderID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def delete_order(order_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = "DELETE FROM ordersinfo WHERE OrderID = %s"
            cur.execute(sql, (order_id,))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")

            con.commit()

        return {"msg": "Order deleted successfully", "OrderID": order_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})
