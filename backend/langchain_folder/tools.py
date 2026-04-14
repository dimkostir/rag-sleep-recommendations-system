from langchain.tools import Tool
from database import sleep_collection, users_collection, evaluation_collection
from datetime import datetime, date
from langchain_community.vectorstores import FAISS
from langchain_huggingface import HuggingFaceEmbeddings
import re
import ast
import math
from bson import ObjectId
import json



# ---------------- Helpers (non-structural) ----------------
def _hhmm(x):
    """Return HH:MM from values like 'HH:MM', 'HH:MM:SS', or datetime.time."""
    try:
        if hasattr(x, "strftime"):
            return x.strftime("%H:%M")
        s = str(x)
        parts = s.split(":")
        if len(parts) >= 2:
            return f"{parts[0].zfill(2)}:{parts[1].zfill(2)}"
        return s
    except Exception:
        return str(x)


def _strip_noise(text: str) -> str:
    """
    Remove Acknowledgements/Footnotes/References blocks and keep a single, clean sentence.
    Also trims newsy headlines like 'HEALTH NEWS'.
    """
    if not isinstance(text, str):
        return ""
    # Remove common noisy sections
    text = re.split(r"(?is)\b(acknowledgements?|footnotes?|references?)\b", text)[0]
    text = re.sub(r"(?is)\bhealth\s*news\b.*", "", text)
    # Keep first sentence (simple heuristic)
    sent = text.strip().split(". ")[0].strip()
    if sent and not sent.endswith("."):
        sent += "."
    return sent


# === Tool 1: Retrieve user's sleep data ===
def get_user_data_by_date(input):
    print("DEBUG user_data_tool input:", input)
    if isinstance(input, dict) and "input" in input:
        input = input["input"]

    if isinstance(input, str):
        uid_m = re.search(r"user_id:\s*([A-Za-z0-9]+)", input)
        date_m = re.search(r"date:\s*([0-9]{4}-[0-9]{2}-[0-9]{2})", input)  # strict ISO
        if not uid_m:
            return "user_id/date not found in prompt."
        user_id = uid_m.group(1)

        record = None
        if date_m:
            d = date_m.group(1)
            record = sleep_collection.find_one({"user_id": user_id, "date": d})
        else:
            # fallbacks: today then most recent
            today_iso = date.today().isoformat()
            record = sleep_collection.find_one({"user_id": user_id, "date": today_iso})
            if not record:
                record = sleep_collection.find_one({"user_id": user_id}, sort=[("date", -1)])

        if not record:
            return "No sleep data found."

        # Shape exact payload (no defaults invented)
        data = {
            "sleep_duration": record.get("sleep_duration"),
            "awakenings": record.get("awakenings"),
            "caffeine_intake": record.get("caffeine_intake"),
            "screen_time": record.get("screen_time"),
            "stress_level": record.get("stress_level"),
            "after_sleep_feeling": record.get("after_sleep_feeling"),
            "room_light": record.get("room_light"),
            "sleep_time": _hhmm(record.get("sleep_time")),
            "wake_time": _hhmm(record.get("wake_time")),
        }

        # Require completeness (agent rule: do NOT invent values)
        required_keys = list(data.keys())
        if any(data[k] is None or data[k] == "" for k in required_keys):
            return "No sleep data found."

        return json.dumps(data)

    return "Invalid input for tool."


user_data_tool = Tool(
    name="GetUserSleepData",
    func=get_user_data_by_date,
    description=(
        "Return user's sleep data as VALID JSON with keys: "
        "sleep_duration, awakenings, caffeine_intake, screen_time, stress_level, "
        "after_sleep_feeling, room_light, sleep_time, wake_time. "
        "Input format: 'user_id: <id>\\ndate: <YYYY-MM-DD>'. "
        "If data is incomplete, returns 'No sleep data found.'."
    ),
)



# === Tool 2: Compute sleep score ===
def compute_sleep_score(input):
    print("DEBUG sleep_score_tool input:", input)
    if isinstance(input, str):
        try:
            input = ast.literal_eval(input)
        except Exception as e:
            return f"Invalid input for sleep score tool: {e}"

    try:
        sleep_duration = float(input["sleep_duration"])   # hours
        awakenings = int(input["awakenings"])             # count
        caffeine_intake = int(input["caffeine_intake"])   # cups
        screen_time = float(input["screen_time"])         # hours
        stress_level = int(input["stress_level"])         # 0..10
        after_sleep_feeling = input["after_sleep_feeling"]
        room_light = input["room_light"]
        sleep_time = _hhmm(input["sleep_time"])           # normalize to HH:MM
        wake_time = _hhmm(input["wake_time"])             # normalize to HH:MM
    except Exception as e:
        return f"Field error: {e}"

    # 1) Sleep Duration points (max 22)
    if sleep_duration >= 7.0:
        sleep_duration_points = 22
    elif sleep_duration >= 6.5:
        sleep_duration_points = 16
    elif sleep_duration >= 6.0:
        sleep_duration_points = 12
    elif sleep_duration >= 5.0:
        sleep_duration_points = 8
    else:
        sleep_duration_points = 4

    # 2) Awakenings (max 20)
    if awakenings == 0:
        awakenings_score = 20
    elif awakenings == 1:
        awakenings_score = 16
    elif awakenings == 2:
        awakenings_score = 12
    elif awakenings <= 4:
        awakenings_score = 6
    else:
        awakenings_score = 0

    # 3) Caffeine (max 8)
    caffeine_score = {0: 8, 1: 5, 2: 2}.get(caffeine_intake, 0)

    # 4) Screen Time (max 8)
    if screen_time < 1.0:
        screen_score = 8
    elif screen_time < 2.0:
        screen_score = 4
    elif screen_time < 3.0:
        screen_score = 2
    else:
        screen_score = 0

    # 5) Stress (max 12) + friendly label
    if stress_level <= 2:
        stress_score = 12
        stress_label = "Zen Master 🧘"
    elif stress_level <= 4:
        stress_score = 9
        stress_label = "Chill 😌"
    elif stress_level <= 6:
        stress_score = 6
        stress_label = "Balanced 🙂"
    elif stress_level <= 8:
        stress_score = 3
        stress_label = "Tense 😬"
    else:
        stress_score = 0
        stress_label = "Overloaded 🔥"

    # 6) After-sleep feeling (max 15)
    feeling_map = {
        "bad": 0,
        "average": 8,
        "good": 12,
        "very good": 15,
    }
    feeling_score = feeling_map.get(str(after_sleep_feeling).lower().strip(), 8)

    # 7) Room Light (max 3)
    room_light_map = {
        "total darkness": 3,
        "minimal light": 1,
        "bright room": 0,
    }
    light_score = room_light_map.get(str(room_light).lower().strip(), 1)

    # 8) Consistency (max 12) based on duration window + bedtime bonus/penalty
    try:
        t1 = datetime.strptime(sleep_time, "%H:%M")
        t2 = datetime.strptime(wake_time, "%H:%M")
        diff = (t2 - t1).seconds / 3600
        if diff <= 0:
            diff += 24
    except Exception:
        diff = sleep_duration

    # --- Duration subscore: 4/7/10 (0..10 before bedtime adj) ---
    if 7.5 <= diff <= 9.0:
        consistency_duration_sub = 10
    elif (6.5 <= diff < 7.5) or (9.0 < diff <= 10.0):
        consistency_duration_sub = 7
    else:
        consistency_duration_sub = 4

    try:
        bt = datetime.strptime(sleep_time, "%H:%M")
        bedtime_hour = bt.hour + bt.minute / 60.0
    except Exception:
        bedtime_hour = 2.5  # fallback

    bedtime_adj = 0
    bedtime_label = "—"

    if 22.0 <= bedtime_hour < 24.0:
        # Best: 22:00–23:59
        bedtime_adj = 2
        bedtime_label = "Perfect sleep time!"
    elif 0.0 <= bedtime_hour < 1.0:
        # OK: 00:00–00:59
        bedtime_adj = 1
        bedtime_label = "Good sleep time!"
    elif 1.0 <= bedtime_hour < 2.0:
        # Moderate: 01:00–01:59
        bedtime_adj = 0
        bedtime_label = "Go to sleep earlier!"
    elif bedtime_hour >= 2.0:
        # Bad (progressive penalty): 02:00→-1, 03:00→-2, 04:00→-3, ≥05:00→-4
        steps = min(4, int(bedtime_hour) - 1)
        bedtime_adj = -steps
        bedtime_label = "Late — go to bed earlier!"
    else:
        # Early (<22:00): good but not top
        bedtime_adj = 1
        bedtime_label = "Early sleep — nice!"

    # Final Consistency (0..12)
    consistency_score = max(0, min(12, consistency_duration_sub + bedtime_adj))

    if consistency_score >= 10:
        consistency_label = "Excellent Consistency"
    elif 7 <= consistency_score < 10:
        consistency_label = "Good Consistency"
    elif 5 <= consistency_score < 7:
        consistency_label = "Fair Consistency"
    else:
        consistency_label = "Poor Consistency"

    # --- Total & normalization to /100 ---
    raw_total = (
        sleep_duration_points
        + awakenings_score
        + caffeine_score
        + screen_score
        + stress_score
        + feeling_score
        + consistency_score
        + light_score
    )
    # New max possible = 100
    MAX_TOTAL = 100
    total_score = round(max(0, min(100, (raw_total / MAX_TOTAL) * 100)))

    category = (
        "🟢 Perfect! You are the sleep master!" if total_score >= 85
        else "🟡 Good! Keep up the good work!" if total_score >= 70
        else "🟠 Average. You can do better than this." if total_score >= 50
        else "🔴 Bad! You need some good sleep..."
    )


    # --- Persist helper fields to Mongo ---
    user_id = input.get("user_id")
    date_str = input.get("date") or date.today().isoformat()
    if user_id:
        sleep_collection.update_one(
            {"user_id": user_id, "date": date_str},
            {
                "$set": {
                    "consistency_score": consistency_score,
                    "consistency_label": consistency_label,
                    "stress_label": stress_label,
                    "category": category,
                    "total_score":total_score,
                    "bedtime_label": bedtime_label,
                    "bedtime_hour": bedtime_hour
                }
            },
            upsert=True,
        )

    return f"Sleep Score: {total_score}/100 ({category})\nSLEEP_SCORE={total_score}/100"


sleep_score_tool = Tool(
    name="SleepScoreEvaluator",
    func=compute_sleep_score,
    description=(
        "Compute sleep score using user's sleep-related data. "
        "Input must be a dictionary with: sleep_duration, awakenings, caffeine_intake, "
        "screen_time, stress_level, after_sleep_feeling, sleep_time, wake_time."
    ),
)

# Load FAISS store (kept as-is)
embedding = HuggingFaceEmbeddings(model_name="sentence-transformers/all-MiniLM-L6-v2")
faiss_store = FAISS.load_local(
    "./faiss_store",
    embeddings=embedding,
    allow_dangerous_deserialization=True,
)


#Score drivers
def _score_drivers(sd, aw, ci, st, stime, room):
    positives = []
    negatives = []

    # Positives
    if 7.0 <= sd <= 9.0: positives.append("Duration")
    if aw <= 1: positives.append("Low awakenings")
    if ci <= 1: positives.append("Low caffeine")
    if stime <= 1.0: positives.append("Low screens")
    if st <= 2: positives.append("Low stress")
    if room == "Total darkness": positives.append("Darkness")

    # Negatives
    if sd < 6.5: negatives.append("Short sleep")
    if aw > 2: negatives.append("Awakenings")
    if ci > 1: negatives.append("Caffeine")
    if stime > 1.0: negatives.append("Late screens")
    if st >= 4: negatives.append("High stress")
    if room in ("Bright room", "Minimal light"): negatives.append("Room light")

    positives = positives[:2] or ["none"]
    negatives = negatives[:2] or ["none"]
    return f"Score drivers: + {', '.join(positives)}; – {', '.join(negatives)}."





# === Tool 3: Knowledge base/ suggestions ===
def kb_suggestions(input):
    print("KB and suggestions tool activated!")

    if isinstance(input, str):
        try:
            input = ast.literal_eval(input)
        except Exception:
            return "Could not load suggestions"

    def _as_float(x, default=0.0):
        try: return float(x)
        except: return default
    def _as_int(x, default=0):
        try: return int(x)
        except: return default

    sd = _as_float(input.get("sleep_duration"))
    aw = _as_int(input.get("awakenings"))
    ci = _as_int(input.get("caffeine_intake"))
    stime = _as_float(input.get("screen_time"))
    stress = _as_int(input.get("stress_level"))
    room = str(input.get("room_light") or "")

    suggestions_list = []

    # --- EXACT mandatory phrases ---
    if sd < 6.5:
        suggestions_list.append("Extend time in bed by 60–90 minutes; bring lights-out earlier.")
    if aw > 2:
        suggestions_list.append("Darker, cooler bedroom and a 20' wind-down.")
    if ci > 1:
        suggestions_list.append("No caffeine after 3 pm")
    if ci >= 3:
        suggestions_list.append("aim ≤2 cups tomorrow")
    if stime > 1.0:
        suggestions_list.append("Power down screens 60–90 minutes before bed.")
    if stress >= 4:
        suggestions_list.append("Do a 10-minute calming routine (breathing/body-scan).")

    if not suggestions_list:
        suggestions_list.append("Everything looks great! Keep a consistent schedule.")

    # --- Top action (priority order) ---
    top_action = None
    if sd < 6.5:
        top_action = "Top action tonight: Extend time in bed by 60–90 minutes; bring lights-out earlier."
    elif ci > 1:
        top_action = "Top action tonight: No caffeine after 3 pm"
    elif stime > 1.0:
        top_action = "Top action tonight: Power down screens 60–90 minutes before bed."
    elif stress >= 4:
        top_action = "Top action tonight: Do a 10-minute calming routine (breathing/body-scan)."
    elif aw > 2:
        top_action = "Top action tonight: Darker, cooler bedroom and a 20' wind-down."

    # De-dup identical suggestion to top_action
    if top_action:
        ta_plain = top_action.replace("Top action tonight: ", "")
        suggestions_list = [s for s in suggestions_list if s != ta_plain]

    # --- Drivers (deterministic; used by the prompt "as-is") ---
    drivers_line = _score_drivers(sd, aw, ci, stress, stime, room)

    # KB lookups (best-effort)
    kb_queries = []
    if sd < 7: kb_queries.append("How does sleep duration affect health?")
    if aw > 2: kb_queries.append("How do frequent awakenings affect sleep quality?")
    if ci > 0: kb_queries.append("What is the effect of caffeine on sleep?")
    if stime > 1.0: kb_queries.append("Does screen time before bed affect sleep?")
    if stress >= 4: kb_queries.append("How does stress impact sleep quality?")

    kb_texts = []
    for q in kb_queries:
        docs = faiss_store.similarity_search(q, k=1)
        if docs:
            cleaned = _strip_noise(docs[0].page_content or "")
            if cleaned:
                kb_texts.append(cleaned)

    # Fallback scientific line if KB empty (pick the most relevant risk)
    if not kb_texts:
        if stress >= 4:
            kb_texts.append("Elevated stress correlates with poorer sleep quality and longer sleep onset.")
        elif ci > 1:
            kb_texts.append("Afternoon/evening caffeine can delay sleep onset and reduce sleep depth.")
        elif stime > 1.0:
            kb_texts.append("Evening screen exposure can delay melatonin and sleep onset.")
        elif sd < 6.5:
            kb_texts.append("Short sleep is linked with impaired recovery and daytime fatigue.")

    bullets = []
    if top_action:
        bullets.append(f"- {top_action}")
    bullets.extend([f"- {s}" for s in suggestions_list])

    suggestions_result = "Personalized suggestions:\n" + "\n".join(bullets)
    suggestions_result += f"\n\n{drivers_line}"
    if kb_texts:
        suggestions_result += "\n\nRelevant scientific info:\n" + "\n".join(kb_texts)

    return suggestions_result




kb_suggestions_tool = Tool(
    name="CombinedSleepSuggestions",
    func=kb_suggestions,
    description=(
        "Use this tool to give the user personalized sleep improvement suggestions (EN), "
        "and support them with concise scientific info from the knowledge base."
    ),
)


# === Tool 4: User's lifestyle data get ===
def get_user_lifestyle(input):
    """
    input: either a dict with user_id or a string 'user_id: ...'
    """
    print("get_user_lifestyle CALLED with:", input)  # Debug print

    # Support both dict and str input for flexibility
    if isinstance(input, dict):
        user_id = input.get("user_id") or input.get("id")
    elif isinstance(input, str):
        match = re.search(r"user_id: *([a-zA-Z0-9]+)", input)
        if match:
            user_id = match.group(1)
        else:
            print("No user_id found in input.")  # Debug print
            return "No user_id found in input."
    else:
        print("Invalid input type")  # Debug print
        return "Invalid input."

    print("Looking for user with id:", user_id)

    record = None
    # Try with _id as ObjectId (Mongo default)
    try:
        record = users_collection.find_one({"_id": ObjectId(user_id)})
        print("Record with ObjectId:", record)
    except Exception as e:
        print("ObjectId lookup failed:", e)
    # Fallback: user_id field
    if not record:
        record = users_collection.find_one({"user_id": user_id})
        print("Record with user_id field:", record)
    if not record:
        print("No data found for user:", user_id)  # Debug print
        return "No data found."

    exercise = record.get("exercise", "N/A") or "N/A"
    nutrition = record.get("nutrition_habits", "N/A") or "N/A"

    print(f"Found exercise: {exercise}, nutrition: {nutrition}")

    return f"Exercise: {exercise}, \nNutrition Habits: {nutrition}"


lifestyle_tool = Tool(
    name="GetUserLifestyle",
    func=get_user_lifestyle,
    description=(
        "Use this tool to retrieve the user's exercise level and nutrition habits from the database. "
        "Pass user_id as input (e.g. 'user_id: <id>')."
    ),
)

TOOLS = [
    lifestyle_tool,
    kb_suggestions_tool,
    sleep_score_tool,
    user_data_tool,
]
