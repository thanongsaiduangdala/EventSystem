import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
APPLY = "--apply" in sys.argv
SCAN_DIRS = ("controllers", "auth", "router", "realtime")

RETURNING_EXEC = re.compile(r'\(\s*(\w+)\s*\+\s*" RETURNING (\w+)"\s*\)')
RETURNING_SPLIT = re.compile(r'\s*\+\s*" RETURNING (\w+)"')
FETCH_ID = r'cur\.fetchone\(\)\s*\[\s*["\']%s["\']\s*\]'
UNIQUE_BLOCK = re.compile(
    r'(?P<i>[ \t]*)except psycopg\.errors\.UniqueViolation:\n'
    r'(?P=i)[ \t]+(?P<raise>raise HTTPException\(status_code=status\.HTTP_409_CONFLICT[^\n]*\))\n'
)
SIMPLE = [
    (re.compile(r'^(\s*)import psycopg\s*$', re.M), r'\1import pymysql'),
    (re.compile(r'\bpsycopg\.Error\b'), 'pymysql.MySQLError'),
    (re.compile(r'\bILIKE\b'), 'LIKE'),
    (re.compile(r'AS TEXT\)'), 'AS CHAR)'),
    (re.compile(r"INTERVAL '(\d+) (day|hour|minute)s?'", re.I), lambda m: f"INTERVAL {m.group(1)} {m.group(2).upper()}"),
    (re.compile(r'INSERT INTO ([^"\n]*?) ON CONFLICT DO NOTHING'), r'INSERT IGNORE INTO \1'),
    (re.compile(r'\.autocommit\s*=\s*True'), '.autocommit(True)'),
    (re.compile(r'FROM event ev,'), 'FROM eventinfo ev,'),
]


def unique_repl(m):
    i = m.group("i")
    return (
        f"{i}except pymysql.err.IntegrityError as err:\n"
        f"{i}    if err.args[0] == 1062:\n"
        f"{i}        {m.group('raise')}\n"
        f"{i}    raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail={{\"data error\": str(err)}})\n"
    )


def convert_returning(text):
    count = 0
    while True:
        m = RETURNING_EXEC.search(text) or RETURNING_SPLIT.search(text)
        if not m:
            break
        col = m.group(2) if m.re is RETURNING_EXEC else m.group(1)
        replacement = m.group(1) if m.re is RETURNING_EXEC else ""
        fetch = re.compile(FETCH_ID % re.escape(col))
        f = fetch.search(text, m.end())
        if f is None or text.count("\n", m.end(), f.start()) > 14:
            raise RuntimeError(f"no matching fetchone for RETURNING {col}")
        text = text[:f.start()] + "cur.lastrowid" + text[f.end():]
        text = text[:m.start()] + replacement + text[m.end():]
        count += 1
    return text, count


def convert(text):
    text, n_ret = convert_returning(text)
    text, n_uniq = UNIQUE_BLOCK.subn(unique_repl, text)
    for pat, rep in SIMPLE:
        text = pat.sub(rep, text)
    return text, n_ret, n_uniq


def main():
    total_ret = total_uniq = changed = 0
    leftovers = []
    for d in SCAN_DIRS:
        base = ROOT / d
        if not base.exists():
            continue
        for p in sorted(base.rglob("*.py")):
            if "__pycache__" in p.parts:
                continue
            raw = p.read_bytes().decode("utf-8-sig")
            crlf = "\r\n" in raw
            text = raw.replace("\r\n", "\n")
            new, n_ret, n_uniq = convert(text)
            if "psycopg" in new or "RETURNING" in new:
                leftovers.append(str(p.relative_to(ROOT)))
            if new != text:
                changed += 1
                total_ret += n_ret
                total_uniq += n_uniq
                if APPLY:
                    if crlf:
                        new = new.replace("\n", "\r\n")
                    p.write_bytes(new.encode("utf-8"))
    print(f"files changed: {changed}")
    print(f"RETURNING converted to lastrowid: {total_ret}")
    print(f"unique-violation handlers converted: {total_uniq}")
    print("still mentioning psycopg/RETURNING:", leftovers or "none")
    print("applied" if APPLY else "dry run only; pass --apply to write changes")


main()
