from fastapi import APIRouter, HTTPException, Depends
from datetime import date
from pydantic_models import UserSleepEntry  
from database import sleep_collection
from dependencies import get_current_user_id

router = APIRouter()

@router.post("/sleep_entry")
def sleep_entry(entry: UserSleepEntry, user_id: str = Depends(get_current_user_id)):
    try:
        print("---- SLEEP ENTRY ROUTE CALLED ----")
        print("Received entry:", entry)
        print("Received user_id from Depends:", user_id)

        # Convert entry to dict
        entry_data = entry.dict()
        entry_data["user_id"] = user_id
        entry_data["date"] = date.today().isoformat()

        # Convert time fields to ISO strings
        for field in ["sleep_time", "wake_time"]:
            if field in entry_data and hasattr(entry_data[field], "isoformat"):
                entry_data[field] = entry_data[field].isoformat()

        print("Final entry_data to save:", entry_data)

        # Check for existing entry on same day
        existing = sleep_collection.find_one({
            "user_id": entry_data["user_id"],
            "date": entry_data["date"]
        })
        if existing:
            print("Record already exists for this user/date.")
            raise HTTPException(status_code=400, detail="There is already a record for this day!")

        result = sleep_collection.insert_one(entry_data)
        print("Mongo insert result:", result.inserted_id)

        return {
            "message": "Record Inserted!",
            "entry_id": str(result.inserted_id)
        }

    except Exception as e:
        print("❌ ERROR in /sleep_entry:", str(e))
        raise HTTPException(status_code=500, detail=f"Internal error: {str(e)}")
