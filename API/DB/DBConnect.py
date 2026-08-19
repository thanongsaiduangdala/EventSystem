import os
import pymysql
from pymysql.cursors import DictCursor
from pymysql.constants import CLIENT

def getConnect():
    try:
        db = pymysql.connect(
            host=os.environ.get('DB_HOST', 'localhost'),
            user=os.environ.get('DB_USER', 'root'),
            password=os.environ.get('DB_PASSWORD', ''),
            database=os.environ.get('DB_NAME', 'reservation_system'),
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