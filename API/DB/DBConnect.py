import pymysql
from pymysql.cursors import DictCursor
from pymysql.constants import CLIENT

def getConnect():
    try:
        db = pymysql.connect(
            host='localhost',
            user='root',
            password='Ilikeminecraft040610',
            database='reservation_system',
            cursorclass=DictCursor,
            client_flag=CLIENT.FOUND_ROWS
        )
        return db
    except Exception as e:
        print(f'Error : {e}')
        return None

if __name__ == "__main__":
    db = getConnect()
    if db:
        print("Connected successfully!")
        db.close()
    else:
        print("Connection failed.")