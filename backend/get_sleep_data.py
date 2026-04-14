from fastapi import APIRouter, Depends, HTTPException, Query
from typing import Optional
from database import sleep_collection
from dependencies import get_current_user_id
from datetime import datetime

router = APIRouter()

@router.get("/get_sleep_data")
def get_sleep_entry(
    date: Optional[str] = Query(None),
    user_id: str = Depends(get_current_user_id)
):
    query = {"user_id": user_id}

    if date:
        try:
            datetime.strptime(date, "%Y-%m-%d")
            query["date"] = date
        except ValueError:
            raise HTTPException(status_code=400, detail="Date wrong format. Use YYYY-MM-DD.")

    results = list(sleep_collection.find(query, {"_id": 0}))

    if not results:
        raise HTTPException(status_code=404, detail="No records.")

    return results
