import pymysql
from fastapi import HTTPException, status
from DB.DBConnect import getConnect
from models.schema import AddTicketTypeRequest, UpdateTicketTypeRequest

async def create_TicketType(req_data: AddTicketTypeRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                INSERT INTO tickettype
                (EventID, TypeName, PriceInKip,
                 Capacity, SaleStartYMDT, SaleEndYMDT)
                VALUES (%s, %s, %s, %s, %s, %s)
            """
            cur.execute(sql, (
                req_data.EventID,
                req_data.TypeName,
                req_data.PriceInKip,
                req_data.Capacity,
                req_data.SaleStart,
                req_data.SaleEnd,
            ))
            con.commit()
            tickettype_id = cur.lastrowid
        return {"msg": "Event created successfully", "event_id": tickettype_id}
    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_all_TicketType():
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("""
                SELECT * FROM tickettype
            """)
            tickettypes = cur.fetchall()

        return {"tickettypes": tickettypes}

    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def get_TicketType_by_id(tickettype_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("""
                SELECT * FROM tickettype WHERE TicketTypeID = %s
            """, (tickettype_id,))
            tickettype = cur.fetchone()

        if tickettype is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        return {"tickettype": tickettype}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})

async def get_TicketType_by_EventID(event_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("""
                SELECT * FROM tickettype WHERE EventID = %s
            """, (event_id,))
            tickettypes = cur.fetchall()

        if not tickettypes:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ticket types not found")

        return {"tickettypes": tickettypes}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})

async def get_TicketType_by_Anything(value: str):
    try:
        con = getConnect()
        with con.cursor() as cur:
            search = f"%{value}%"
            cur.execute("""
                SELECT * FROM tickettype
                WHERE TypeName LIKE %s
                   OR CAST(EventID AS CHAR) LIKE %s
                   OR CAST(PriceInKip AS CHAR) LIKE %s
                   OR CAST(Capacity AS CHAR) LIKE %s
                   OR CAST(SaleStartYMDT AS CHAR) LIKE %s
                   OR CAST(SaleEndYMDT AS CHAR) LIKE %s
            """, (search, search, search, search, search, search))
            tickettypes = cur.fetchall()

        if not tickettypes:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ticket types not found")

        return {"tickettypes": tickettypes}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})


async def update_TicketType(req_data: UpdateTicketTypeRequest):
    try:
        con = getConnect()
        with con.cursor() as cur:
            sql = """
                UPDATE tickettype
                SET EventID = %s,
                    TypeName = %s,
                    PriceInKip = %s,
                    Capacity = %s,
                    SaleStartYMDT = %s,
                    SaleEndYMDT = %s
                WHERE TicketTypeID = %s
            """
            cur.execute(sql, (
                req_data.EventID,
                req_data.TypeName,
                req_data.PriceInKip,
                req_data.Capacity,
                req_data.SaleStart,
                req_data.SaleEnd,
                req_data.TicketTypeID,
            ))

            if cur.rowcount == 0:
                con.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ticket not found")

            con.commit()

        return {"msg": "Ticket updated successfully", "ticket_type_id": req_data.TicketTypeID}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})

async def delete_TicketType(tickettype_id: int):
    try:
        con = getConnect()
        with con.cursor() as cur:
            cur.execute("DELETE FROM tickettype WHERE TicketTypeID = %s", (tickettype_id,))
            rows_deleted = cur.rowcount
            con.commit()

        if rows_deleted == 0:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="tickettype not found")

        return {"msg": "tickettype deleted successfully", "tickettype_id": tickettype_id}

    except HTTPException:
        raise
    except pymysql.MySQLError as err:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={"data error": str(err)})