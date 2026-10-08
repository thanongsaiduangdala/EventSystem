import os
import pathlib
import re
import secrets

path = pathlib.Path(".env")
lines = path.read_text(encoding="utf-8-sig").splitlines() if path.exists() else []
drop = re.compile(r"^\s*(DB_\w+|SUPABASE_DB_URL|DATABASE_URL)\s*=")
kept = [line.rstrip("\r") for line in lines if line.strip() and not drop.match(line)]
have = {line.split("=", 1)[0].strip() for line in kept if "=" in line}
defaults = {
    "GMAIL_USER": "change-me@gmail.com",
    "GMAIL_APP_PASSWORD": "change-me",
    "JWT_SECRET_KEY": secrets.token_hex(32),
    "JWT_ALGORITHM": "HS256",
    "JWT_EXPIRE_MINUTES": "10080",
}
for key, value in defaults.items():
    if key not in have:
        kept.append(f"{key}={value}")
kept += [
    "DB_HOST=" + os.environ.get("DB_HOST", "localhost"),
    "DB_PORT=" + os.environ.get("DB_PORT", "3306"),
    "DB_USER=" + os.environ.get("DB_USER", "root"),
    "DB_PASSWORD=" + os.environ.get("DBPW", ""),
    "DB_NAME=" + os.environ.get("DB_NAME", "reservation_system"),
]
path.write_text("\n".join(kept) + "\n", encoding="utf-8")
print("Updated .env with the MySQL settings")
