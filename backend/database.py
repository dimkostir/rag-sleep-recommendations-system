from pymongo import MongoClient
from dotenv import load_dotenv
import os


load_dotenv()

#MongoDB configuration

MONGO_URI = os.getenv("MONGODB_URI")
MONGO_DB = os.getenv("MONGODB_DB")



client = MongoClient(MONGO_URI)
db = client[MONGO_DB]

MONGO_USERS_COLLECTION = os.getenv("MONGODB_USERS_COLLECTION")
users_collection = db[MONGO_USERS_COLLECTION]

MONGO_SLEEP_COLLECTION = os.getenv("MONGODB_SLEEP_COLLECTION")
sleep_collection = db[MONGO_SLEEP_COLLECTION]

MONGO_EVALUATION_COLLECTION = os.getenv("MONGODB_EVALUATION_COLLECTION")
evaluation_collection = db[MONGO_EVALUATION_COLLECTION]

MONGO_PSQI_COLLECTION = os.getenv("MONGODB_PSQI_COLLECTION")
psqi_collection = db[MONGO_PSQI_COLLECTION]

MONGO_PSQI_EVALUATION_COLLECTION = os.getenv("MONGODB_PSQI_EVALUATION_COLLECTION")
psqi_evaluation_collection = db[MONGO_PSQI_EVALUATION_COLLECTION]

MONGO_STATS_COLLECTION = os.getenv("MONGODB_STATS_COLLECTION")
stats_collection = db[MONGO_STATS_COLLECTION]
stats_collection.create_index([("user_id", 1)], unique=True, name="uniq_user_id")