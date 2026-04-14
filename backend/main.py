from fastapi import FastAPI
from register import router as register_router  
from user_login import router as login_router
from sleep_entry import router as sleep_entry_router
from langchain_folder.agent_routes import router as agent_router
from history import router as history_router
from psqi import router as psqi_router
from psqi_agent.psqi_agent_routes import router as psqi_agent_router
from email_notifications.scheduler import start_scheduler
from psqi_history import router as psqi_history_router
from menu_stats import router as stats_router
from change_pswd import router as change_pswd_router

#App
app = FastAPI()

#middleware use
from fastapi.middleware.cors import CORSMiddleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://127.0.0.1:5173",
        "http://localhost:5173",
        "http://10.17.123.176:5173",
        "http://192.168.1.3:5173",
        "*"
    ],                           
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Accept", "Origin", "ngrok-skip-browser-warning"],
    
)

app.include_router(register_router)
app.include_router(login_router)
app.include_router(agent_router)
app.include_router(sleep_entry_router) 
app.include_router(history_router)
app.include_router(psqi_router)
app.include_router(psqi_agent_router)
app.include_router(psqi_history_router)
app.include_router(change_pswd_router)
app.include_router(stats_router)

# Start the email-scheduler when the app starts
@app.on_event("startup")
async def startup_event():
    start_scheduler()

@app.get("/")
async def root():
    return {"message": "Sleep app is running with email scheduler"}