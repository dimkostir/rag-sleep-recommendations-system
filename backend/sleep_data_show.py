from fastapi import APIRouter, Depends
from datetime import date
from database import sleep_collection, evaluation_collection
from dependencies import get_current_user_id

router = APIRouter()

@router.get("/sleep_entry/{entry_date}")
def get_sleep_entry(
    entry_date: date,
    user_id: str = Depends(get_current_user_id)
):
    user_id = int(user_id)

    # Find sleep data
    sleep_data = sleep_collection.find_one({
        "user_id": user_id,
        "date": entry_date.isoformat()
    })

    # Find agent result (if any)
    agent_result = evaluation_collection.find_one({
        "user_id": user_id,
        "date": entry_date.isoformat()
    })

    return {
        "sleep_data": sleep_data,
        "agent_result": agent_result.get("agent_result") if agent_result else None
    }


@router.get("/sleep_entry/history")
def get_sleep_history(
    user_id: str = Depends(get_current_user_id)
):
    user_id = int(user_id)

    entries = list(sleep_collection.find({"user_id": user_id}).sort("date", -1))

    return {
        "total_entries": len(entries),
        "history": entries
    }
