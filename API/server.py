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
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)

os.makedirs(BASE_DIR / "static" / "event_images", exist_ok=True)
app.mount("/static", StaticFiles(directory=str(BASE_DIR / "static")), name="static")

ROUTER_DIR = "router"
if os.path.exists(ROUTER_DIR):
    for root, dirs, files in os.walk(ROUTER_DIR):
        for filename in files:
            if filename.endswith(".py") and filename != "__init__.py":
                filepath = os.path.join(root, filename)
                module_name = filepath.replace(os.sep, ".")[:-3]
                route_module = importlib.import_module(module_name)
                if hasattr(route_module, "router"):
                    app.include_router(route_module.router)
else:
    print(f"Warning: Directory {ROUTER_DIR} not found")