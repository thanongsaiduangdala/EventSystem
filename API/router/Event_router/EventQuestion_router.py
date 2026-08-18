from fastapi import APIRouter
from models.schema import (
    AddEventQuestionInfo,
    UpdateEventQuestionInfo,
    AddEventQuestionType,
    UpdateEventQuestionType,
)
from controllers.Event_Controllers.EventQuestion_Controllers import (
    create_event,
    get_all_events,
    get_event_by_id,
    get_eventquestions_by_event_id,
    update_event,
    delete_event,
    create_eventquestiontype,
    get_all_eventquestiontypes,
    get_eventquestiontype_by_id,
    update_eventquestiontype,
    delete_eventquestiontype,
)

router = APIRouter(prefix="/eventquestion", tags=["EventQuestion"])


# ---------------- eventquestioninfo ----------------

@router.post("/")
async def add_event(req_data: AddEventQuestionInfo):
    return await create_event(req_data)


@router.get("/")
async def list_events():
    return await get_all_events()


@router.put("/")
async def edit_event(req_data: UpdateEventQuestionInfo):
    return await update_event(req_data)


@router.post("/type")
async def add_eventquestiontype(req_data: AddEventQuestionType):
    return await create_eventquestiontype(req_data)


@router.get("/type")
async def list_eventquestiontypes():
    return await get_all_eventquestiontypes()


@router.get("/type/{eventquestiontype_id}")
async def get_eventquestiontype(eventquestiontype_id: int):
    return await get_eventquestiontype_by_id(eventquestiontype_id)


@router.put("/type")
async def edit_eventquestiontype(req_data: UpdateEventQuestionType):
    return await update_eventquestiontype(req_data)


@router.delete("/type/{eventquestiontype_id}")
async def remove_eventquestiontype(eventquestiontype_id: int):
    return await delete_eventquestiontype(eventquestiontype_id)


@router.get("/event/{event_id}")
async def get_events_by_event(event_id: int):
    return await get_eventquestions_by_event_id(event_id)


@router.get("/{eventquestion_id}")
async def get_event(eventquestion_id: int):
    return await get_event_by_id(eventquestion_id)


@router.delete("/{eventquestion_id}")
async def remove_event(eventquestion_id: int):
    return await delete_event(eventquestion_id)