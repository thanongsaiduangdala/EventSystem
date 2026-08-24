from fastapi import FastAPI
import importlib
import os
from pathlib import Path
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from fastapi.staticfiles import StaticFiles
load_dotenv()

BASE_DIR = Path(__file__).resolve().parent  # API/

app = FastAPI(title="FastAPI Back-end System")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:8081"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)

os.makedirs(BASE_DIR / "static" / "event_images", exist_ok=True)
app.mount("/static", StaticFiles(directory=str(BASE_DIR / "static")), name="static")

ROUTER_DIR = BASE_DIR / "router"
if ROUTER_DIR.exists():
    for root, dirs, files in os.walk(ROUTER_DIR):
        for filename in files:
            if filename.endswith(".py") and filename != "__init__.py":
                filepath = os.path.join(root, filename)
                module_name = Path(filepath).relative_to(BASE_DIR).with_suffix("").as_posix().replace("/", ".")
                route_module = importlib.import_module(module_name)
                if hasattr(route_module, "router"):
                    app.include_router(route_module.router)
else:
    print(f"Warning: Directory {ROUTER_DIR} not found")