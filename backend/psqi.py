from fastapi import APIRouter, Depends, HTTPException
from datetime import datetime, date
from typing import Any, Dict
from pydantic_models import PSQI  
from database import psqi_collection
from dependencies import get_current_user_id

router = APIRouter()


def _to_float(x: Any, default: float = 0.0) -> float:
    try:
        return float(x)
    except Exception:
        return default


def _to_int(x: Any, default: int = 0) -> int:
    try:
        return int(x)
    except Exception:
        return default


def calculate_psqi_score(answers: Dict[str, Any]):
    """
    Calculate 7 PSQI components and total score
    Q10 / partner fileds -> only stored
    """
    from datetime import datetime as dt

    # --- 1) Sleep duration (Q4) ---
    q4 = _to_float(answers.get("q4", 0))
    # 0: >7h, 1: 6-7h, 2: 5-6h, 3: <=5h
    duration = 0 if q4 > 7 else 1 if 6 < q4 <= 7 else 2 if 5 < q4 <= 6 else 3

    # --- 2) Sleep disturbance (sum Q5b–Q5j) ---
    distb_sum = sum([
        _to_int(answers.get(k, 0)) for k in
        ["q5b", "q5c", "q5d", "q5e", "q5f", "q5g", "q5h", "q5i", "q5j"]
    ])
    # 0:0, 1:1–9, 2:10–18, 3:19–27
    disturbance = 0 if distb_sum == 0 else 1 if distb_sum <= 9 else 2 if distb_sum <= 18 else 3

    # --- 3) Sleep latency (Q2 + Q5a) ---
    q2 = _to_float(answers.get("q2", 0))
    q2_score = 0 if q2 <= 15 else 1 if q2 <= 30 else 2 if q2 <= 60 else 3
    latency_sum = q2_score + _to_int(answers.get("q5a", 0))
    latency = 0 if latency_sum == 0 else 1 if latency_sum <= 2 else 2 if latency_sum <= 4 else 3

    # --- 4) Daytime dysfunction (Q8 + Q9) ---
    day_sum = _to_int(answers.get("q8", 0)) + _to_int(answers.get("q9", 0))
    daytime_dysfunction = 0 if day_sum == 0 else 1 if day_sum <= 2 else 2 if day_sum <= 4 else 3

    # --- 5) Habitual sleep efficiency (Q1,Q3,Q4) ---
    hse_score = 3  # worst by default
    try:
        bed_time_str = answers.get("q1")
        wake_time_str = answers.get("q3")
        if not isinstance(bed_time_str, str) or not isinstance(wake_time_str, str):
            raise ValueError("q1/q3 must be 'HH:MM' strings")

        bed_time = dt.strptime(bed_time_str, "%H:%M")
        wake_time = dt.strptime(wake_time_str, "%H:%M")

        tib_hours = (wake_time - bed_time).total_seconds() / 3600.0
        if tib_hours < 0:
            tib_hours += 24.0

        sleep_hours = _to_float(answers.get("q4", 0))
        # Sanity checks 
        if tib_hours < 0.5:
            raise ValueError("Time in bed under 30 minutes. Please check Q1/Q3.")
        if sleep_hours > tib_hours + 0.01:
            raise ValueError("Hours of sleep (Q4) exceed time in bed (Q1–Q3).")
        if tib_hours > 16:
            raise ValueError("Unusually long time in bed (>16h). Please verify wake/bed time.")

        hse = (sleep_hours / tib_hours) * 100 if tib_hours > 0 else 0.0
        hse_score = 0 if hse > 85 else 1 if hse > 75 else 2 if hse > 65 else 3
    except ValueError as ve:
        raise ve
    except Exception:
        hse_score = 3

    sleep_quality = _to_int(answers.get("q6", 0))
    medication = _to_int(answers.get("q7", 0))

    component_scores = {
        "duration": duration,
        "disturbance": disturbance,
        "latency": latency,
        "daytime_dysfunction": daytime_dysfunction,
        "sleep_efficiency": hse_score,
        "sleep_quality": sleep_quality,
        "medication": medication,
    }

    total_score = sum(component_scores.values())
    return total_score, component_scores


@router.post("/psqi")
def submit_psqi(psqi: PSQI, user_id: str = Depends(get_current_user_id)):
    """
    PSQI entry for current user ( today )
    saves answers and scores
    """
    try:
        print("---- PSQI ROUTE CALLED ----")
        print("Received answers:", psqi.answers)
        print("User_id from Depends:", user_id)

        today_str = date.today().isoformat()

        # unique user date
        if psqi_collection.find_one({"user_id": user_id, "date": today_str}):
            print("Duplicate PSQI record found for user/date.")
            raise HTTPException(status_code=400, detail="A PSQI entry already exists for today.")

        # calculate score
        try:
            total_score, sub_scores = calculate_psqi_score(dict(psqi.answers))
        except ValueError as ve:
            raise HTTPException(status_code=422, detail=str(ve))

        entry_data = {
            "user_id": user_id,
            "date": today_str,
            "answers": dict(psqi.answers),      
            "total_score": total_score,
            "sub_scores": sub_scores,
            "created_at": datetime.utcnow(),
        }
        print("Inserting entry_data:", entry_data)
        result = psqi_collection.insert_one(entry_data)
        print("Mongo insert result:", result.inserted_id)

        return {
            "message": "PSQI record inserted!",
            "entry_id": str(result.inserted_id),
            "total_score": total_score,
            "sub_scores": sub_scores,
            "interpretation": ("Good sleep quality" if total_score < 5 else "Poor sleep quality"),
        }

    except HTTPException:
        raise
    except Exception as e:
        print("❌ ERROR in /psqi:", str(e))
        raise HTTPException(status_code=500, detail=f"Internal error: {e}")
