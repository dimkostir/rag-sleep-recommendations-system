# change_pswd.py
from fastapi import APIRouter, Depends, HTTPException, status, Response
from pydantic import BaseModel, Field
from database import users_collection  
from dependencies import get_current_user_id
from bson import ObjectId
import bcrypt

router = APIRouter()

class ChangePasswordIn(BaseModel):
    old_password: str = Field(..., min_length=1)
    new_password: str = Field(..., min_length=4)  

@router.post("/change_pswd", status_code=status.HTTP_204_NO_CONTENT)
def change_password(payload: ChangePasswordIn, user_id: str = Depends(get_current_user_id)):
    try:
        oid = ObjectId(user_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid user id")

    user = users_collection.find_one({"_id": oid})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    stored_hash = user.get("password")
    if not stored_hash:
        raise HTTPException(status_code=400, detail="Password not set")

    if not bcrypt.checkpw(payload.old_password.encode(), stored_hash.encode()):
        raise HTTPException(status_code=400, detail="Old password is incorrect")

    if payload.old_password == payload.new_password:
        raise HTTPException(status_code=400, detail="New password must be different")

    new_hash = bcrypt.hashpw(payload.new_password.encode(), bcrypt.gensalt()).decode()
    users_collection.update_one({"_id": oid}, {"$set": {"password": new_hash}})

    return Response(status_code=status.HTTP_204_NO_CONTENT)
