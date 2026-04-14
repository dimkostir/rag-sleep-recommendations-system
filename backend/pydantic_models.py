from pydantic import BaseModel, EmailStr,Field
from datetime import datetime, time
from typing import  Annotated



class SleepDataInput(BaseModel):
    user_id: str
    date: str  # YYYY-MM-DD
    
class ScoreInput(BaseModel):
    sleep_duration: float
    awakenings: int
    caffeine_intake: int
    screen_time: float
    stress_level: int
    after_sleep_feeling: str
    sleep_time: str  # "HH:MM"
    wake_time: str   # "HH:MM"


class UserSleepEntry(BaseModel):
    sleep_duration: Annotated[float, Field(gt=0, le=24)]
    awakenings: Annotated[int, Field(ge=0, le=10)]
    caffeine_intake: Annotated[int, Field(ge=0, le=10)]
    screen_time: Annotated[float, Field(ge=0, le=10)]
    stress_level: Annotated[int, Field(ge=0, le=10)]
    after_sleep_feeling: str
    room_light: str    
    sleep_time: time
    wake_time: time

class CreateUser(BaseModel):
    username: str
    name:str
    surname:str
    age:int
    gender: str
    weight:float
    email:EmailStr
    password:str
    exercise: str
    nutrition_habits:str

class UserOut(BaseModel):
    id: str
    username: str
    email: EmailStr
    created_at: datetime

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class PSQI(BaseModel):
    answers: dict  
