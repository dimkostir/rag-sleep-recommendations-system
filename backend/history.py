from fastapi import APIRouter, Depends, Query
from dependencies import get_current_user_id
from database import evaluation_collection

router = APIRouter()

# full history
@router.get("/history/all")
def get_full_history(user_id: str = Depends(get_current_user_id), limit: int = 30):
    print("1")
    history = list(
        evaluation_collection.find({"user_id": user_id}).sort("date", -1).limit(limit)
    )
    for entry in history:
        entry["_id"] = str(entry["_id"])
    return {"history": history}

# date range
@router.get("/history")
def get_history(
    date: str = Query(None, description="YYYY-MM-DD"),
    start_date: str = Query(None, description="YYYY-MM-DD"),
    end_date: str = Query(None, description="YYYY-MM-DD"),
    user_id: str = Depends(get_current_user_id),
):
    print("2")
    query = {"user_id": user_id}
    if date:
        query["date"] = date
    elif start_date and end_date:
        query["date"] = {"$gte": start_date, "$lte": end_date}
    elif start_date:
        query["date"] = {"$gte": start_date}
    elif end_date:
        query["date"] = {"$lte": end_date}

    history = list(
        evaluation_collection.find(query).sort("date", -1)
    )
    for entry in history:
        entry["_id"] = str(entry["_id"])
    return {"history": history}

# scores only
@router.get("/history/scores")
def get_scores_history(user_id: str = Depends(get_current_user_id)):
    print("3")
    cursor = evaluation_collection.find(
        {"user_id": user_id},
        {"_id": 0, "date": 1, "sleep_score": 1}
    ).sort("date", -1)
    history = list(cursor)
    return {"scores": history}
