"""
  Tools for the Sleep Agent
- Return machine-readable dicts (no free text parsing)
- Use Pydantic arg schemas (StructuredTool)

Exports (import in agent):
  - get_user_data_tool
  - sleep_score_tool
  - lifestyle_tool
  - evidence_tool
  - trends_tool
"""

from __future__ import annotations
from typing import List, Optional, Any, Dict
from pydantic import BaseModel
from pydantic_models import SleepDataInput, ScoreInput, LifestyleInput, EvidenceInput, TrendInput
from langchain.tools import StructuredTool
from datetime import datetime, timedelta
import re
# --- DB collections ---
from database import users_collection, sleep_collection, evaluation_collection


# Load FAISS store
from langchain_community.vectorstores import FAISS
from langchain_huggingface import HuggingFaceEmbeddings

embedding = HuggingFaceEmbeddings(model_name="sentence-transformers/all-MiniLM-L6-v2")
faiss_store = FAISS.load_local(
    "./faiss_store",
    embeddings=embedding,
    allow_dangerous_deserialization=True
)


# GetUserSleepData 




def get_user_data_by_date(args: SleepDataInput):
    """Return the user's sleep record for a specific date."""
    rec = sleep_collection.find_one({"user_id": args.user_id, "date": args.date})
    if not rec:
        return {}
    # Ensure ObjectId is stringified, if present
    if "_id" in rec:
        rec["_id"] = str(rec["_id"])
    return rec


get_user_data_tool = StructuredTool.from_function(
    name="GetUserSleepData",
    func=get_user_data_by_date,
    description="Get user's sleep data for a specific date (returns a dict).",
    args_schema=SleepDataInput,
)


# SleepScoreEvaluator



def _parse_hours_minutes(t: str) -> float:
    h, m = t.split(":")
    return int(h) + int(m) / 60.0


def compute_sleep_score(args: ScoreInput):
    """Compute subscores (0–10 each) and a total scaled to 100.
    - Subscores remain 0–10 for interpretability.
    - Total is scaled from the 7 subscores (max 70) to a 0–100 scale.
    """
    # Duration (simple heuristic)
    d = float(args.sleep_duration)
    duration_score = 10 if d >= 8 else 8 if d >= 7 else 6 if d >= 6 else 3

    # Awakenings
    a = int(args.awakenings)
    awakenings_score = 10 if a == 0 else 8 if a == 1 else 6 if a == 2 else 4 if a == 3 else 3

    # Caffeine intake (count of caffeinated drinks, regardless of timing here)
    c = int(args.caffeine_intake)
    caffeine_score = 10 if c == 0 else 7 if c == 1 else 4 if c == 2 else 3

    # Screen time (hours in the evening)
    st = float(args.screen_time)
    screen_score = 10 if st <= 1 else 7 if st <= 2 else 4 if st <= 3 else 3

    # Stress (1..5) → invert to score; clamp between 3..10
    sl = int(args.stress_level)
    stress_score = max(3, min(10, 11 - sl * 2))  # 1→9, 2→7, 3→5, 4→3, 5→3

    # Subjective feeling mapping
    feeling_map = {
        "very_good": 10,
        "good": 8,
        "bad": 5,
        "very_bad": 3,
    }
    feeling_key = args.after_sleep_feeling.lower().replace(" ", "_")
    feeling_score = feeling_map.get(feeling_key, 6)

    # Consistency: based on time-in-bed window (approx.)
    # NOTE: Without historical data, we approximate using nightly interval length.
    try:
        t_s = _parse_hours_minutes(args.sleep_time)
        t_w = _parse_hours_minutes(args.wake_time)
        interval = (t_w - t_s) % 24.0
    except Exception:
        interval = d  # fallback on reported duration
    consistency_score = 10 if 7.5 <= interval <= 9 else 7 if (6 <= interval < 7.5 or 9 < interval <= 10) else 4

    subs = {
        "duration": duration_score,
        "awakenings": awakenings_score,
        "caffeine": caffeine_score,
        "screen": screen_score,
        "stress": stress_score,
        "feeling": feeling_score,
        "consistency": consistency_score,
    }

    raw_total = sum(subs.values())  # max 70
    total = int(round(raw_total * (100.0 / 70.0)))  # scale to 0–100

    label = (
        "Perfect" if total >= 85 else
        "Good" if total >= 70 else
        "Average" if total >= 50 else
        "Bad"
    )

    return {"total": total, "label": label, "subscores": subs}


sleep_score_tool = StructuredTool.from_function(
    name="SleepScoreEvaluator",
    func=compute_sleep_score,
    description="Compute sleep score (0–100) and subscores (0–10 each).",
    args_schema=ScoreInput,
)


# GetUserLifestyle

def get_user_lifestyle(args: LifestyleInput):
    """Return user's lifestyle basics from users collection.
    Falls back to empty strings when not present.
    """
    uid = args.user_id
    rec = users_collection.find_one({"_id": uid}) or users_collection.find_one({"id": uid})
    if not rec:
        return {"exercise": "", "nutrition": ""}
    return {
        "exercise": rec.get("exercise", ""),
        "nutrition": rec.get("nutrition", ""),
    }


lifestyle_tool = StructuredTool.from_function(
    name="GetUserLifestyle",
    func=get_user_lifestyle,
    description="Get user's exercise and nutrition preferences (dict).",
    args_schema=LifestyleInput,
)


# Scientific evidence

def get_scientific_evidence(args: EvidenceInput):
    """Return up to 3 concise claims with clean citations from FAISS.
    If no FAISS store is available, returns an empty evidence list.
    """
    store = globals().get("faiss_store", None) or faiss_store
    if store is None:
        return {"evidence": []}

    out = []
    seen_titles = set()
    for q in args.queries[:3]:
        try:
            docs = store.similarity_search(q, k=1)
        except Exception:
            continue
        if not docs:
            continue
        d = docs[0]
        text = d.page_content or ""
        # Remove acknowledgements/footnotes/references noise (best-effort)
        clean = re.split(r"(?is)\b(acknowledgements?|footnotes?|references?)\b", text)[0].strip()
        claim = (clean.split(". ")[0] + ".") if clean else ""
        meta = d.metadata or {}
        title = meta.get("title", meta.get("source", "")).strip()
        if title in seen_titles:
            continue
        seen_titles.add(title)
        out.append({
            "claim": claim,
            "citation": {
                "author": meta.get("author", ""),
                "year": str(meta.get("year", "")),
                "title": title,
                "url": meta.get("url", ""),
            },
        })
    return {"evidence": out}


evidence_tool = StructuredTool.from_function(
    name="GetScientificEvidence",
    func=get_scientific_evidence,
    description="Return concise evidence (claim + citation) for given queries.",
    args_schema=EvidenceInput,
)


# V2: Trends (7/30-day averages)

def get_user_trends(args: TrendInput):
    docs = list(
        evaluation_collection.find({"user_id": args.user_id, "sleep_score": {"$ne": None}})
        .sort("date", -1)
        .limit(30)
    )
    scores = [int(d.get("sleep_score", 0)) for d in docs if d.get("sleep_score") is not None][::-1]
    if not scores:
        return {"avg7": None, "avg30": None}

    def avg(n: int) -> int:
        arr = scores[-n:] if len(scores) >= n else scores
        return int(round(sum(arr) / len(arr)))

    return {"avg7": avg(7), "avg30": avg(30)}


trends_tool = StructuredTool.from_function(
    name="GetUserTrends",
    func=get_user_trends,
    description="Return 7- and 30-day average sleep scores for the user.",
    args_schema=TrendInput,
)


# Export ordered list for convenience

TOOLS = [
    get_user_data_tool,
    sleep_score_tool,
    lifestyle_tool,
    evidence_tool,
    trends_tool,
]
