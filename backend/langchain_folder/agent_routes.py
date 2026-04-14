from fastapi import APIRouter, Depends
from dependencies import get_current_user_id
from .agent import run_sleep_agent
from datetime import date, datetime, timedelta
from database import evaluation_collection, sleep_collection, stats_collection
import re
from typing import Dict, List, Optional

router = APIRouter()

@router.post("/agent/evaluate")
def evaluate_sleep_for_today(user_id: str = Depends(get_current_user_id)):
    today_str = date.today().isoformat()

    query = """
Evaluate my sleep for today as a product-grade sleep coach. Friendly, supportive, concise copy (mobile app UI). Write in English.

TOOLS AVAILABLE: GetUserSleepData, SleepScoreEvaluator, GetUserLifestyle, CombinedSleepSuggestions.
When you take an Action, it MUST be exactly one of these names. Do NOT invent actions.

Plan (STRICT ORDER):
1) Call GetUserSleepData using the 'user_id' and 'date' lines at the end. It returns VALID JSON (sleep_duration, awakenings, caffeine_intake, screen_time, stress_level, after_sleep_feeling, room_light, sleep_time, wake_time). Use it as-is; do NOT re-parse.
2) Call SleepScoreEvaluator with that JSON PLUS {"user_id":"<id>","date":"YYYY-MM-DD"}. Do NOT invent values.
3) Call GetUserLifestyle and parse to {"exercise":"<value>","nutrition":"<value>"}.
4) Call CombinedSleepSuggestions exactly once with the MERGED dict in valid JSON. THIS STEP IS MANDATORY when sleep data exists.

If NO SLEEP DATA:
- If GetUserSleepData returns 'No sleep data found.', do NOT call SleepScoreEvaluator or CombinedSleepSuggestions and do NOT invent numbers. You may call GetUserLifestyle.
- Then write the Final Answer with general but actionable advice: include 'Personalized suggestions:' (first bullet MUST be 'Top action tonight: ...') and a short 'Relevant scientific info:' block. If the KB was not used, provide up to two 'Agent insight:' lines instead.

Copy & formatting rules (STRICT):
- Output ONE final block only; do NOT repeat or echo the same block twice. Do NOT mention tools, steps, or thoughts.
- ≤140 words for the main text (TTips are excluded). Warm, positive tone (e.g., “Here’s the plan for tonight.”).
- Use the EXACT '- Top action tonight: ...' line AS RETURNED by CombinedSleepSuggestions. Do NOT recompute or alter wording. Drop any duplicate bullet.
- Always include a Room Light bullet using the exact wording from the rules below.
- If CombinedSleepSuggestions includes a line starting with 'Score drivers:', COPY IT VERBATIM in the 'Score drivers:' slot. Do NOT recompute.
- If no scientific lines are surfaced by tools, write 1–2 general evidence lines (safe, non-technical).
- In "Personalized suggestions" keep exactly 2 bullets: (1) Top action tonight, (2) Room Light.
- Add: "Score drivers: + X, Y; – A, B." Use comma-separated items, 1–2 per side, each ≤3 words, and end with a period.
- Add: "Next 24h plan:" with 3 numbered steps. **Step 1 must be IDENTICAL (character-by-character) to the Top action line INCLUDING the 'Top action tonight: ' prefix.** Steps 2–3 must be distinct from step 1 and from each other; verb-first, concrete, 1 line each.
- After the plan, add ONE line titled "Agent's opinion:" — choose from this library (≤80 chars):
  • A consistent wake time will lift your score fastest.
  • Tonight’s quick win: protect the hour before bed.
  • Stress drove your score; a 10-min unwind can offset it.
  • Caffeine after 3 pm is the bottleneck—fix that first.
  • Solid duration; tighten wind-down to reduce arousal.
  • Low awakenings—great base to build strong sleep.
  • Great darkness; now trim late screens for deeper sleep.
  • Your body likes rhythm; aim for ±30 min wake window.
- Never paste raw tool output; rewrite concisely.
- When printing times like 'HH:MM:SS', show only 'HH:MM'. Duration rounded to 1 decimal (e.g., 6.8h).

Top action priorities (MANDATORY EXACT WORDING; do NOT paraphrase):
- If sleep_duration < 6.5 → EXACTLY: 'Extend time in bed by 60–90 minutes; bring lights-out earlier.'
- if caffeine_intake > 1 → EXACTLY: 'No caffeine after 3 pm' (and if ≥3 → 'aim ≤2 cups tomorrow').
- if screen_time > 1.0 → EXACTLY: 'Power down screens 60–90 minutes before bed.'
- If stress_level ≥ 4 → EXACTLY: 'Do a 10-minute calming routine (breathing/body-scan).'
- Else if awakenings > 2 → EXACTLY: 'Darker, cooler bedroom and a 20' wind-down.'

Room Light (MANDATORY fixed wording, no changes):
- If room_light = 'Minimal light' → EXACTLY: 'Room light is a bit high, try to reduce it.'
- If room_light = 'Bright room' → EXACTLY: 'Bright rooms harm sleep. Sleep in full darkness for best quality.'
- If room_light = 'Total darkness' → EXACTLY: 'Great! Keep sleeping in the dark.'

Scoring labels (consistency):
- 0–49: Poor | 50–69: Average | 70–84: Good | 85–100: Excellent.

TTips block (for UI tooltips — STRICT format):
- After 'Relevant scientific info:' add a friendly lead-in line: 'Here are some quick tips:'
- Then print a block titled 'TTips:' with 2–3 lines.
- EACH tip line MUST start with: 'TTIP: <key>|<text>'
- Allowed <key>: top_action, score, caffeine, screens, stress, duration, awakenings, room_light, schedule.
- <text> must be ≤60 characters, plain sentence, no emojis.
- Choose keys relevant to today's data.
- **Bedtime-aware rule (MANDATORY schedule tip):** Parse sleep_time HH:MM as 24h. Let H = hour + minutes/60.
  • If 22.0 ≤ H < 24.0 → include: TTIP: schedule|Keep 22:00–23:59 window (±15 min).
  • If 0.0 ≤ H < 1.0 → include: TTIP: schedule|Protect your pre-midnight wind-down.
  • If 1.0 ≤ H < 2.0 → include: TTIP: schedule|Shift lights-out 20–30 min earlier tonight.
  • If H ≥ 2.0 → include: TTIP: schedule|Bring lights-out 30–45 min earlier for 3 nights.
  • If H < 22.0 → include: TTIP: schedule|Early bedtime helps; keep it steady.
- Example microcopy library (pick 1–2 extra lines if relevant):
  • top_action → 'Biggest single-night gain comes from this.'
  • score → 'Consistency lifts score more than any hack.'
  • caffeine → 'After 3 pm, even small doses linger.'
  • screens → 'Dim and distance reduce blue-light impact.'
  • stress → 'Box breathing 4-4-4-4 lowers arousal fast.'
  • duration → 'Aim 7–9h; protect the first sleep cycle.'
  • awakenings → 'Limit fluids 2h pre-bed to reduce wakeups.'
  • room_light → 'Darkness boosts melatonin timing.'
  • schedule → 'Wake within ±30 min, even after bad nights.'

Strict output template (print ONCE; fill the values):
Final Answer:
Your sleep score for today is: {score}/100 ({label}).
Sleep highlights: Bedtime {HH:MM} → Wake {HH:MM} | Duration {hours}h | Awakenings {n}.
Exercise habits: {exercise}. Nutrition habits: {nutrition}.

Personalized suggestions:
- Top action tonight: ...
- Room Light: ...

Score drivers: + ..., ...; – ..., ....

Next 24h plan:
1) Top action tonight: ...
2) ...
3) ...

Agent's opinion: ...

Relevant scientific info:
...

Here are some quick tips:
TTips:
TTIP: <key>|<≤60 chars tip>
TTIP: <key>|<≤60 chars tip>
TTIP: <key>|<≤60 chars tip>

Use the available tools before replying.

user_id: {USER_ID_WILL_BE_APPENDED_BELOW}
date: {DATE_WILL_BE_APPENDED_BELOW}
"""

    # ---- Run agent
    result = run_sleep_agent(query, user_id, today_str)
    print("AGENT RESULT:", result)

    # ---- Extract suggestions (optional)
    if "Personalized suggestions:" in result:
        suggestions_str = result.split("Personalized suggestions:")[1]
        if "Relevant scientific info:" in suggestions_str:
            suggestions_str = suggestions_str.split("Relevant scientific info:")[0]
        suggestions_str = suggestions_str.strip()
    else:
        suggestions_str = "No personalized suggestions found."

    # ---- Pull today's extra fields
    latest_sleep_doc = sleep_collection.find_one(
        {"user_id": user_id, "date": today_str},
        {
            "consistency_score": 1, "consistency_label": 1,
            "stress_level": 1, "stress_label": 1,
            "category": 1, "bedtime_label": 1, "bedtime_hour": 1
        }
    )
    consistency_score = latest_sleep_doc.get("consistency_score") if latest_sleep_doc else None
    consistency_label = latest_sleep_doc.get("consistency_label") if latest_sleep_doc else None
    stress_level      = latest_sleep_doc.get("stress_level") if latest_sleep_doc else None
    stress_label      = latest_sleep_doc.get("stress_label") if latest_sleep_doc else None
    category          = latest_sleep_doc.get("category") if latest_sleep_doc else None
    bedtime_label     = latest_sleep_doc.get("bedtime_label") if latest_sleep_doc else None
    bedtime_hour      = latest_sleep_doc.get("bedtime_hour") if latest_sleep_doc else None

    # ---- Parse sleep_score from agent text
    sleep_score: Optional[int] = None
    score_match = re.search(r"(\d{1,3})/100", result or "")
    if score_match:
        sleep_score = max(0, min(100, int(score_match.group(1))))  # clamp 0..100

    # ---- Helpers
    def score_badge(score: Optional[int]) -> str:
        if score is None:
            return "No badge"
        if score >= 90: return "Sleep Master"
        if score >= 80: return "Early Bird"
        if score >= 60: return "Night Owl"
        return "Sleep Rookie"

    def calc_streak(user_id: str, date_str: str, score_for_date: Optional[int], threshold: int = 70) -> int:
        """Count consecutive days with score ≥ threshold up to and including date_str."""
        def ok(d: date) -> bool:
            doc = evaluation_collection.find_one(
                {"user_id": user_id, "date": d.isoformat()},
                {"sleep_score": 1, "_id": 0}
            )
            s = doc.get("sleep_score") if doc else None
            return isinstance(s, int) and s >= threshold

        try:
            cur = datetime.fromisoformat(date_str).date()
        except Exception:
            cur = date.today()

        if isinstance(score_for_date, int):
            if score_for_date < threshold:
                return 0
            streak = 1
        else:
            if not ok(cur):
                return 0
            streak = 1  # <-- μέσα στο else

        cur -= timedelta(days=1)
        while ok(cur):
            streak += 1
            cur -= timedelta(days=1)

        return streak

    def user_level(entry_count: int) -> int:
        if entry_count > 25: return 6
        if entry_count > 20: return 5
        if entry_count > 15: return 4
        if entry_count > 10: return 3
        if entry_count > 5:  return 2
        return 1

    def calculate_stats_from_db(uid: str) -> Dict[str, int]:
        pipeline = [
            {"$match": {"user_id": uid, "sleep_score": {"$type": "int"}}},
            {"$group": {
                "_id": None,
                "avg": {"$avg": "$sleep_score"},
                "pb": {"$max": "$sleep_score"},
                "count": {"$sum": 1},
            }},
        ]
        agg = list(evaluation_collection.aggregate(pipeline))
        if not agg:
            return {"average_score": 0, "personal_best": 0, "count": 0}
        return {
            "average_score": int(round(agg[0]["avg"])),
            "personal_best": int(agg[0]["pb"]),
            "count": int(agg[0]["count"]),
        }

    # ---- Badge / Streak
    badge  = score_badge(sleep_score)
    streak = calc_streak(user_id, today_str, sleep_score, threshold=70)

    # ---- INSERT evaluation FIRST (no derived metrics here yet)
    insert_res = evaluation_collection.insert_one({
        "user_id": user_id,
        "date": today_str,
        "agent_result": result,
        "sleep_score": sleep_score,
        "suggestions": suggestions_str,
        "created_at": datetime.utcnow(),
        "consistency_score": consistency_score,
        "consistency_label": consistency_label,
        "stress_level": stress_level,
        "stress_label": stress_label,
        "category": category,
        "bedtime_label": bedtime_label,
        "bedtime_hour": bedtime_hour
    })
    inserted_id = insert_res.inserted_id

    # ---- Compute avg/pb/count/level FROM DB (now includes today's record)
    stats = calculate_stats_from_db(user_id) or {}
    average_score = stats.get("average_score", sleep_score or 0)
    personal_best = stats.get("personal_best", sleep_score or 0)
    entry_count   = stats.get("count", 1)
    level         = user_level(entry_count)

    # ---- Upsert 1-per-user stats
    stats_collection.update_one(
        {"user_id": user_id},
        {
            "$set": {
                "level": level,
                "badge": badge,
                "average_score": average_score,
                "personal_best": personal_best
            },
            "$setOnInsert": {"created_at": datetime.utcnow()},
            "$currentDate": {"updated_at": True},
        },
        upsert=True,
    )

    # ---- Update the inserted evaluation with derived metrics
    evaluation_collection.update_one(
        {"_id": inserted_id},
        {"$set": {
            "streak": streak,
            "badge": badge,
            "personal_best": personal_best,
            "average_score": average_score,
            "level": level
        }}
    )

    print(result)
    return {
        "result": result,
        "sleep_score": sleep_score,
        "badge": badge,
        "streak": streak,
        "personal_best": personal_best,
        "average_score": average_score,
        "level": level,
        "consistency_score": consistency_score,
        "consistency_label": consistency_label,
        "stress_level": stress_level,
        "stress_label": stress_label,
        "category": category,
        "bedtime_label": bedtime_label,
        "bedtime_hour": bedtime_hour
    }
