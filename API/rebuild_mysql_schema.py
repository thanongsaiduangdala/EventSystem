"""
Rebuild the local MySQL database from scratch using Mysql\\001_fresh_schema.sql.

Use this when the existing tables are out of date (missing columns, wrong NULL rules).
It DROPS the whole database (named in .env as DB_NAME) and creates it again, empty.
After this, run migrate_supabase_to_mysql.py to copy your data back in from Supabase.

Run from the API folder:
    venv\\Scripts\\python.exe rebuild_mysql_schema.py
"""
import re
import sys
from pathlib import Path

import pymysql
from dotenv import dotenv_values

HERE = Path(__file__).resolve().parent


def split_statements(sql):
    """Split a simple SQL script into statements (no DELIMITER blocks, no ';' inside strings)."""
    sql = re.sub(r"^\s*--.*$", "", sql, flags=re.M)  # drop comment lines
    return [s.strip() for s in sql.split(";") if s.strip()]


def main():
    env = dotenv_values(HERE / ".env")
    db_name = env.get("DB_NAME") or "reservation_system"

    candidates = [HERE / "Mysql" / "001_fresh_schema.sql", HERE / "001_fresh_schema.sql"]
    schema_path = next((p for p in candidates if p.exists()), None)
    if schema_path is None:
        sys.exit("Could not find Mysql\\001_fresh_schema.sql. Copy it from the kit's zip first.")

    text = schema_path.read_text(encoding="utf-8-sig")
    # Safety check: make sure this is the NEW MySQL schema, not an old or PostgreSQL one.
    if "ActiveMembershipKey" not in text or "AUTO_INCREMENT" not in text:
        sys.exit(f"{schema_path} is not the expected MySQL schema from files__2_.zip. "
                 "Copy that file over it and try again.")
    statements = split_statements(text)

    print(f"Schema file : {schema_path}")
    print(f"Database    : {db_name} on {env.get('DB_HOST') or 'localhost'}")
    print(f"\nWARNING: this DELETES the database '{db_name}' and everything in it.")
    if input("Type YES to continue: ").strip() != "YES":
        sys.exit("Cancelled. Nothing was changed.")

    try:
        con = pymysql.connect(
            host=env.get("DB_HOST") or "localhost",
            port=int(env.get("DB_PORT") or 3306),
            user=env.get("DB_USER") or "root",
            password=env.get("DB_PASSWORD") or "",
            charset="utf8mb4",
            autocommit=True,
        )
    except Exception as err:
        sys.exit(f"Could not connect to MySQL: {err}")

    cur = con.cursor()
    cur.execute(f"DROP DATABASE IF EXISTS `{db_name}`")
    cur.execute(f"CREATE DATABASE `{db_name}` CHARACTER SET utf8mb4")
    cur.execute(f"USE `{db_name}`")

    for i, stmt in enumerate(statements, 1):
        try:
            cur.execute(stmt)
        except Exception as err:
            sys.exit(f"Statement {i} failed: {err}\n---\n{stmt[:300]}")

    cur.execute("SHOW TABLES")
    tables = [r[0] for r in cur.fetchall()]
    cur.execute(
        "SELECT COUNT(*) FROM information_schema.columns "
        "WHERE table_schema = %s AND table_name = 'organizermember' AND column_name = 'MemberStatusID'",
        (db_name,),
    )
    has_col = cur.fetchone()[0] == 1
    con.close()

    print(f"\nDone: {len(statements)} statements ran, {len(tables)} tables created.")
    print("Check organizermember.MemberStatusID exists:", "yes" if has_col else "NO - something is wrong")
    print("\nNext: venv\\Scripts\\python.exe migrate_supabase_to_mysql.py")


if __name__ == "__main__":
    main()
