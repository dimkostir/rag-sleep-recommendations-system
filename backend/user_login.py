from fastapi import APIRouter, HTTPException
from pydantic_models import UserLogin
from database import users_collection
from jwt_handler import create_access_token
import bcrypt

router = APIRouter()

@router.post("/user_login")
def user_login(user: UserLogin):
    print("LOGIN ROUTE TRIGGERED")
    existing_user = users_collection.find_one({"email": user.email})
    if not existing_user:
        raise HTTPException(status_code=401, detail="Invalid credentials!")

    stored_pw = existing_user["password"]
    if isinstance(stored_pw, str):
        stored_pw = stored_pw.encode("utf-8")

    if not bcrypt.checkpw(user.password.encode("utf-8"), stored_pw):
        raise HTTPException(status_code=401, detail="Invalid credentials!")

    token = create_access_token(str(existing_user["_id"]))
    return {
        "message": "Login successful!",
        "access_token": token,
        "token_type": "bearer"
    }
