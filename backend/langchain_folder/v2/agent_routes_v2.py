from fastapi import APIRouter, Depends, HTTPException
from dependencies import get_current_user_id
from .agent_v2 import run_sleep_agent
from datetime import date, datetime, timedelta
from database import evaluation_collection
from pydantic_models import SubScores, Score, Lifestyle, Trends, AnalysisOut
import json
import re

"""
Agent routes (drop-in replacement)
- Forces JSON-only output from the agent (coach view + science view)
- Strong runtime validation with Pydantic
- Persists results to MongoDB (evaluation_collection)
- Returns a compact UI-ready card plus the full analysis JSON
- Includes simple gamification: badge, streak, personal best, average, level

"""

router = APIRouter()

# ---------------------------
# JSON schema string for the prompt (guidance for the LLM)
# ---------------------------
JSON_SCHEMA = """
{
  "score": { "total": int, "label": "Perfect|Good|Average|Bad",
    "subscores": { "duration": int, "awakenings": int, "caffeine": int,
                   "screen": int, "stress": int, "feeling": int, "consistency": int }
  },
  "lifestyle": { "exercise": str, "nutrition": str },
  "summary": {
    "tldr": str,
    "verdict": str,
    "top_action_for_tonight": str,
    "secondary_actions": [str]
  },
  "science": {
    "plain_explainer": str,
    "mechanisms": [str],
    "ranges": [ { "metric": str, "your_value": str, "recommended": str } ],
    "citations": [ { "author": str, "year": str, "title": str, "url": str } ]
  },
  "trends": { "avg7": int|null, "avg30": int|null },
  "confidence": "low|medium|high"
}
"""

# ---------------------------
# Helpers
# ---------------------------

def _safe_json_loads(s: str):
    """Parse leniently: try normal loads; if it fails, extract the largest {...} block."""
    try:
        return json.loads(s)
    except Exception:
        m = re.search(r"\{.*\}", s, re.DOTALL)
        if not m:
            raise
        return json.loads(m.group(0))


def _pick_badge(score: int) -> str:
    if score >= 85:
        return "Sleep Master"
    if score >= 70:
        return "Well Rested"
    if score >= 50:
        return "Getting There"
    return "Sleep Rookie"


def _compute_level(avg_score: int) -> str:
    if avg_score >= 85:
        return "Platinum"
    if avg_score >= 70:
        return "Gold"
    if avg_score >= 55:
        return "Silver"
    if avg_score >= 40:
        return "Bronze"
    return "Starter"


def _compute_streak(user_id: str, today: date) -> int:
    """Count consecutive days (ending today or yesterday if today missing) with an evaluation entry."""
    # Try starting from today; if not present, start from yesterday
    def has_entry(d: date) -> bool:
        return evaluation_collection.find_one({"user_id": user_id, "date": d.isoformat()}) is not None

    current = today if has_entry(today) else (today - timedelta(days=1))
    streak = 0
    while has_entry(current):
        streak += 1
        current -= timedelta(days=1)
    return streak


def _personal_best(user_id: str) -> int:
    doc = evaluation_collection.find_one({"user_id": user_id, "sleep_score": {"$ne": None}}, sort=[("sleep_score", -1)])
    return int(doc["sleep_score"]) if doc and doc.get("sleep_score") is not None else 0


def _average_score(user_id: str) -> int:
    pipeline = [
        {"$match": {"user_id": user_id, "sleep_score": {"$ne": None}}},
        {"$group": {"_id": None, "avg": {"$avg": "$sleep_score"}}}
    ]
    agg = list(evaluation_collection.aggregate(pipeline))
    if agg:
        return int(round(agg[0]["avg"]))
    return 0


def _fallback_trends(user_id: str) -> Trends:
    """Compute 7d/30d averages as a fallback if the agent didn't populate trends."""
    docs = list(
        evaluation_collection.find({"user_id": user_id, "sleep_score": {"$ne": None}})
        .sort("date", -1)
        .limit(30)
    )
    scores = [int(d.get("sleep_score", 0)) for d in docs][::-1]
    if not scores:
        return Trends()

    def avg(n: int) -> int:
        arr = scores[-n:] if len(scores) >= n else scores
        return int(round(sum(arr) / len(arr)))

    return Trends(avg7=avg(7), avg30=avg(30))


# ---------------------------
# Route
# ---------------------------
@router.post("/agent/evaluate")
def evaluate_sleep_for_today(user_id: str = Depends(get_current_user_id)):
    today_str = date.today().isoformat()

    # Prompt that forces JSON-only output including a friendly coach view and a scientific view
    query = f"""
You are a sleep coach and scientific explainer. Use only the available tools.
Goal: Evaluate today's sleep for user_id: {user_id}, date: {today_str}.
Steps:
1) Fetch today's sleep data.
2) Compute the sleep score and all sub-scores.
3) Fetch user's lifestyle (exercise, nutrition) and incorporate it.
4) Retrieve 1–3 concise, relevant pieces of scientific evidence (no acknowledgements/footnotes).
5) If possible, compute 7- and 30-day trends using the trends tool.

WRITE IN ENGLISH (friendly level). Return STRICT JSON ONLY with this schema:
{JSON_SCHEMA}

Rules:
- Keep summary.tldr to 1–2 sentences.
- science.plain_explainer: 80–120 words, no jargon.
- Use short author–year citations; include URL if available.
- No markdown, no extra commentary outside JSON.
"""

    # Run the agent and parse the response
    raw = run_sleep_agent(query, user_id, today_str)
    try:
        data = _safe_json_loads(raw)
        analysis = AnalysisOut.model_validate(data)  # Pydantic v2 validation
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Invalid analysis JSON: {e}")

    # Persist analysis to MongoDB
    score_total = int(analysis.score.total)
    evaluation_collection.update_one(
        {"user_id": user_id, "date": today_str},
        {"$set": {
            "user_id": user_id,
            "date": today_str,
            "sleep_score": score_total,
            "sub_scores": analysis.score.subscores.model_dump(),
            "lifestyle": analysis.lifestyle.model_dump(),
            "summary": analysis.summary.model_dump(),
            "science": analysis.science.model_dump(),
            "trends": analysis.trends.model_dump(),
            "confidence": analysis.confidence,
            "updated_at": datetime.utcnow(),
        }},
        upsert=True,
    )

    # Compute gamification metrics
    badge = _pick_badge(score_total)
    streak = _compute_streak(user_id, date.today())
    personal_best = _personal_best(user_id)
    average_score = _average_score(user_id)
    level = _compute_level(average_score)

    # Ensure trends exist
    trends = analysis.trends
    if trends.avg7 is None or trends.avg30 is None:
        trends = _fallback_trends(user_id)

    # UI-ready compact card + full analysis JSON
    ui_card = {
        "score": score_total,
        "label": analysis.score.label,
        "tldr": analysis.summary.tldr,
        "top_action": analysis.summary.top_action_for_tonight,
        "secondary": analysis.summary.secondary_actions,
        "trends": trends.model_dump(),
        "badge": badge,
    }

    # Also include legacy top-level fields if your UI already uses them
    return {
        "ui_card": ui_card,
        "analysis": analysis.model_dump(),
        "sleep_score": score_total,
        "badge": badge,
        "streak": streak,
        "personal_best": personal_best,
        "average_score": average_score,
        "level": level,
    }
