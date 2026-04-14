from apscheduler.schedulers.background import BackgroundScheduler
from datetime import datetime
from fastapi_mail import FastMail, MessageSchema
from email_notifications.email_config import conf
from pymongo import MongoClient
import pytz
import asyncio
from database import users_collection, sleep_collection

fm = FastMail(conf)

def check_and_notify_users():
    today = datetime.now().strftime("%Y-%m-%d")
    users = list(users_collection.find({}))


    for user in users:
        user_id = str(user["_id"])
        entry = sleep_collection.find_one({"user_id": user_id, "date": today})

        if not entry:
            user_name = user.get("name","there")


            html_body = f"""
            <html>
              <head>
                <style>
                  body {{
                    font-family: Arial, sans-serif;
                    background-color: #f4f4f9;
                    padding: 20px;
                  }}
                  .container {{
                    background-color: #ffffff;
                    border-radius: 10px;
                    padding: 20px;
                    box-shadow: 0 2px 5px rgba(0,0,0,0.1);
                  }}
                  h2 {{
                    color: #4a148c;
                  }}
                  p {{
                    font-size: 14px;
                    color: #333333;
                  }}
                  .footer {{
                    margin-top: 20px;
                    font-size: 12px;
                    color: #888888;
                  }}
                </style>
              </head>
              <body>
                <div class="container">
                  <h2>Hello {user_name} 👋</h2>
                  <p>Don’t forget to add your sleep data for today!</p>
                  <a href="http://192.168.1.3:5173/" class="button">
                     Add sleep data now!
                  </a>
                  <p class="footer">— Sleep App Notifications</p>
                </div>
              </body>
            </html>
            """

            message = MessageSchema(
                subject="Reminder: Sleep Data Missing",
                recipients=[user["email"]],
                body=html_body,
                subtype="html"
            )
            asyncio.run(fm.send_message(message))
            print(f"Reminder sent to {user['email']}")

def start_scheduler():
    scheduler = BackgroundScheduler(timezone=pytz.timezone("Europe/Athens"))
    scheduler.add_job(check_and_notify_users, "cron", hour=00, minute=28)  # Every Day at 20:00
    scheduler.start()
    print("***Email scheduler started***")
