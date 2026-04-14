from fastapi import APIRouter, Depends
from dependencies import get_current_user_id
from database import stats_collection, users_collection
from bson import ObjectId

router = APIRouter()

@router.get("/stats")
def get_stats(user_id: str = Depends(get_current_user_id)):
    print("Stats router activated")

    # 1) USer stats
    stats_doc = stats_collection.find_one(
        {"user_id": user_id},
        {"_id": 0, "user_id": 1, "level": 1, "average_score": 1, "badge": 1}
    ) or {}

    # 2) Name from users collections
    name = "there"
    try:
        user_doc = None
        if ObjectId.is_valid(user_id):
            user_doc = users_collection.find_one(
                {"_id": ObjectId(user_id)},
                {"_id": 0, "name": 1, "email": 1}
            )
        if not user_doc:
            user_doc = users_collection.find_one(
                {"user_id": user_id},
                {"_id": 0, "name": 1, "email": 1}
            )

        if user_doc:
            name = (
                user_doc.get("name")
                or (user_doc.get("email", "").split("@")[0] if user_doc.get("email") else None)
                or "there"
            )
    except Exception as e:
        print(f"/stats name lookup error: {e}")

    # level
    raw_level = stats_doc.get("level", 0)
    try:
        level = int(raw_level)
    except (TypeError, ValueError):
        level = 0

    # average_score
    raw_avg = stats_doc.get("average_score", 0.0)
    try:
        average_score = float(raw_avg)
    except (TypeError, ValueError):
        average_score = 0.0

    badge = stats_doc.get("badge", "None")

    return {
        "user_id": user_id,
        "name": name,
        "level": level,
        "average_score": average_score,
        "badge": badge,
    }
