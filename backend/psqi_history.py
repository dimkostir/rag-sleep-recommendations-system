from fastapi import APIRouter, Depends, Query
from dependencies import get_current_user_id
from database import psqi_evaluation_collection

router = APIRouter()


# date range
@router.get("/psqi_history")
def get_psqi_history(
    date: str = Query(None, description="YYYY-MM-DD"),
    start_date: str = Query(None, description="YYYY-MM-DD"),
    end_date: str = Query(None, description="YYYY-MM-DD"),
    user_id: str = Depends(get_current_user_id),
):
    print("PSQI route triggered")
    print("user_id:", user_id)
    print("date:",date, "start:",start_date, "end:", end_date)
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
        psqi_evaluation_collection.find(query).sort("date", -1)
    )
    for entry in history:
        entry["_id"] = str(entry["_id"])
    return {"history": history}

