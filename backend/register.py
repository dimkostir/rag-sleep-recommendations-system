from fastapi import APIRouter, HTTPException
from pydantic_models import CreateUser
from database import users_collection
from datetime import datetime
import bcrypt

router = APIRouter()

@router.post("/register")
def register(user: CreateUser):
    print("REGISTER ROUTE TRIGGERED")
    if users_collection.find_one({"email": user.email}):
        raise HTTPException(status_code=400, detail="ERROR: email already in use.")
    
    if users_collection.find_one({"username": user.username}):
        raise HTTPException(status_code=400, detail="ERROR: username already in use.")

    hashed_pw = bcrypt.hashpw(user.password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")
    
    

    new_user = {
        "username": user.username,
        "name": user.name,
        "surname": user.surname,
        "age": user.age,
        "weight": user.weight,
        "email": user.email,
        "password": hashed_pw,
        "exercise": user.exercise,
        "gender":user.gender,
        "nutrition_habits": user.nutrition_habits,
        "created_time": datetime.utcnow()
    }

    result = users_collection.insert_one(new_user)
    return {"message": "Account created!", "user_id": str(result.inserted_id)}
