"""
Copy all data from Supabase (PostgreSQL) into the local MySQL database.

- Reads from Supabase in READ-ONLY mode (nothing in Supabase is changed).
- WIPES the matching tables in MySQL first, then copies every row, keeping the same IDs.
- MySQL settings come from .env (DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME).

Run from the API folder:
    venv\\Scripts\\python.exe -m pip install "psycopg[binary]"
    venv\\Scripts\\python.exe migrate_supabase_to_mysql.py
"""
import getpass
import json
import sys
from pathlib import Path

import psycopg
import pymysql
from dotenv import dotenv_values

BATCH = 500


def convert(value):
    """Turn PostgreSQL-only Python types into something MySQL accepts."""
    if isinstance(value, (dict, list)):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, memoryview):
        return bytes(value)
    return value


def main():
    env = dotenv_values(Path(__file__).with_name(".env"))
    my_cfg = dict(
        host=env.get("DB_HOST") or "localhost",
        port=int(env.get("DB_PORT") or 3306),
        user=env.get("DB_USER") or "root",
        password=env.get("DB_PASSWORD") or "",
        database=env.get("DB_NAME") or "reservation_system",
        charset="utf8mb4",
        autocommit=False,
    )

    url = sys.argv[1] if len(sys.argv) > 1 else getpass.getpass(
        "Paste your Supabase connection string (input is hidden): "
    ).strip()
    if not url:
        sys.exit("No connection string given.")

    print("Connecting to Supabase ...")
    try:
        pg = psycopg.connect(url, connect_timeout=20)
    except Exception as err:
        sys.exit(f"Could not connect to Supabase: {type(err).__name__}. "
                 "Check the string, the password (special characters must be URL-encoded), "
                 "and try the 'Session pooler' string if the direct one fails.")
    pg.read_only = True

    print("Connecting to MySQL ...")
    try:
        my = pymysql.connect(**my_cfg)
    except Exception as err:
        sys.exit(f"Could not connect to MySQL: {err}")

    pg_cur = pg.cursor()
    my_cur = my.cursor()

    pg_cur.execute(
        "SELECT table_name FROM information_schema.tables "
        "WHERE table_schema = 'public' AND table_type = 'BASE TABLE'"
    )
    pg_tables = {r[0].lower(): r[0] for r in pg_cur.fetchall()}

    my_cur.execute("SHOW TABLES")
    my_tables = [r[0] for r in my_cur.fetchall()]

    plan = []
    for t in my_tables:
        src = pg_tables.get(t.lower())
        if src is None:
            print(f"  (skip) {t}: not found in Supabase")
            continue
        pg_cur.execute(f'SELECT COUNT(*) FROM public."{src}"')
        plan.append((t, src, pg_cur.fetchone()[0]))

    print(f"\nTables to copy into MySQL database '{my_cfg['database']}':")
    for t, _, n in plan:
        print(f"  {t:28s} {n:>8d} rows")
    total = sum(n for _, _, n in plan)
    print(f"  {'TOTAL':28s} {total:>8d} rows")

    print("\nWARNING: this ERASES every row currently in those MySQL tables first.")
    if input("Type YES to continue: ").strip() != "YES":
        sys.exit("Cancelled. Nothing was changed.")

    my_cur.execute("SET FOREIGN_KEY_CHECKS = 0")
    my_cur.execute("SET SESSION sql_mode = CONCAT(@@sql_mode, ',NO_AUTO_VALUE_ON_ZERO')")

    # Supabase allows NULL in these columns (free orders have no payment type or proof;
    # ID verifications not yet reviewed have no reviewer). Make MySQL allow it too.
    for stmt in (
        "ALTER TABLE `ordersinfo` MODIFY `PaymentTypeID` INT NULL",
        "ALTER TABLE `ordersinfo` MODIFY `ProveOfPayment` VARCHAR(255) NULL",
        "ALTER TABLE `identityverification` MODIFY `ReviewedByAccountID` INT NULL",
    ):
        try:
            my_cur.execute(stmt)
        except Exception as err:
            print(f"  note: could not run [{stmt}]: {err}")

    results = []
    for t, src, expected in plan:
        try:
            my_cur.execute(f"SHOW COLUMNS FROM `{t}`")
            my_cols = {r[0].lower(): r[0] for r in my_cur.fetchall()}

            pg_cur.execute(f'SELECT * FROM public."{src}"')
            pg_names = [d.name for d in pg_cur.description]
            use = [(i, my_cols[n.lower()]) for i, n in enumerate(pg_names) if n.lower() in my_cols]
            skipped = [n for n in pg_names if n.lower() not in my_cols]
            if skipped:
                print(f"  note: {t}: columns not in MySQL, ignored: {', '.join(skipped)}")
            if not use:
                raise RuntimeError("no matching columns")

            idx = [i for i, _ in use]
            col_sql = ", ".join(f"`{c}`" for _, c in use)
            ph = ", ".join(["%s"] * len(use))
            sql = f"INSERT INTO `{t}` ({col_sql}) VALUES ({ph})"

            my_cur.execute(f"TRUNCATE TABLE `{t}`")
            copied = 0
            while True:
                rows = pg_cur.fetchmany(BATCH)
                if not rows:
                    break
                my_cur.executemany(sql, [[convert(r[i]) for i in idx] for r in rows])
                copied += len(rows)
            my.commit()
            print(f"  copied {t}: {copied} rows")
            results.append((t, expected, copied, None))
        except Exception as err:
            my.rollback()
            print(f"  FAILED {t}: {err}")
            results.append((t, expected, 0, str(err)))

    my_cur.execute("SET FOREIGN_KEY_CHECKS = 1")
    my.commit()

    print("\nChecking row counts ...")
    bad = 0
    for t, expected, _, err in results:
        my_cur.execute(f"SELECT COUNT(*) FROM `{t}`")
        got = my_cur.fetchone()[0]
        ok = (got == expected and err is None)
        bad += 0 if ok else 1
        print(f"  {'OK ' if ok else 'BAD'} {t:28s} supabase={expected:<8d} mysql={got}")

    pg.close()
    my.close()
    print("\nDone: all tables match." if bad == 0 else f"\nDone, but {bad} table(s) need attention (see BAD above).")


if __name__ == "__main__":
    main()
