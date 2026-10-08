import os

import pymysql
from pymysql.cursors import DictCursor


def getConnect():
    """Return a MySQL connection (rows come back as dicts), or None on failure."""
    try:
        return pymysql.connect(
            host=os.environ.get("DB_HOST", "localhost"),
            port=int(os.environ.get("DB_PORT", "3306")),
            user=os.environ.get("DB_USER", "root"),
            password=os.environ.get("DB_PASSWORD", ""),
            database=os.environ.get("DB_NAME", "reservation_system"),
            charset="utf8mb4",
            cursorclass=DictCursor,
            autocommit=False,
        )
    except Exception:
        # Never print the exception: it can contain credentials.
        print("MySQL connection failed")
        return None


if __name__ == "__main__":
    db = getConnect()
    if db:
        print("Connected successfully!")
        db.close()
    else:
        print("Connection failed.")
