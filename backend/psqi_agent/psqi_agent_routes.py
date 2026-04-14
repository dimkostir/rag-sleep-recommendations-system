from fastapi import APIRouter, Depends, HTTPException
from dependencies import get_current_user_id
from database import psqi_collection, psqi_evaluation_collection
from datetime import date, datetime, timedelta
from groq import RateLimitError

from .psqi_agent import run_psqi_agent  

# === mapping ===
PSQI_MAPPING = {
    "q1": {
        "question": "Q1: What time have you usually gone to bed at night? (Bed time, e.g., 23:00)",
        "explanation": "The time you usually go to bed each night."
    },
    "q2": {
        "question": "Q2: How long (in minutes) has it taken you to fall asleep each night?",
        "explanation": "The average number of minutes it takes you to fall asleep after going to bed."
    },
    "q3": {
        "question": "Q3: What time have you usually gotten up in the morning? (Wake time, e.g., 07:30)",
        "explanation": "The time you usually wake up each morning."
    },
    "q4": {
        "question": "Q4: How many hours of actual sleep did you get at night? (This may be different from the number of hours you spent in bed.)",
        "explanation": "The total number of hours you actually slept, not just spent in bed."
    },
    "q5a": {
        "question": "Q5a: During the past month, how often have you had trouble sleeping because you could not get to sleep within 30 minutes?",
        "explanation": "How frequently you had difficulty falling asleep within 30 minutes."
    },
    "q5b": {
        "question": "Q5b: During the past month, how often have you woken up in the middle of the night or early morning?",
        "explanation": "How frequently you woke up during the night or too early in the morning."
    },
    "q5c": {
        "question": "Q5c: During the past month, how often have you had to get up to use the bathroom?",
        "explanation": "How often you woke up to go to the bathroom during the night."
    },
    "q5d": {
        "question": "Q5d: During the past month, how often have you had trouble sleeping because you could not breathe comfortably?",
        "explanation": "How often you had difficulty sleeping due to breathing discomfort."
    },
    "q5e": {
        "question": "Q5e: During the past month, how often have you coughed or snored loudly during your sleep?",
        "explanation": "How frequently coughing or snoring disturbed your sleep."
    },
    "q5f": {
        "question": "Q5f: During the past month, how often have you felt too cold during the night?",
        "explanation": "How often you felt too cold while trying to sleep."
    },
    "q5g": {
        "question": "Q5g: During the past month, how often have you felt too hot during the night?",
        "explanation": "How often you felt too hot while trying to sleep."
    },
    "q5h": {
        "question": "Q5h: During the past month, how often have you had bad dreams?",
        "explanation": "How frequently you experienced bad dreams that disturbed your sleep."
    },
    "q5i": {
        "question": "Q5i: During the past month, how often have you had pain while sleeping?",
        "explanation": "How often pain kept you from sleeping well."
    },
    "q5j": {
        "question": "Q5j: During the past month, how often have you had trouble sleeping for some other reason (describe reason)?",
        "explanation": "How frequently other reasons (not listed) disturbed your sleep."
    },
    "q6": {
        "question": "Q6: During the past month, how would you rate your overall sleep quality?",
        "explanation": "Your overall perception of sleep quality (0=Very good, 3=Very bad)."
    },
    "q7": {
        "question": "Q7: During the past month, how often have you taken medicine (prescribed or 'over the counter') to help you sleep?",
        "explanation": "How frequently you used medication or supplements to help you sleep."
    },
    "q8": {
        "question": "Q8: During the past month, how often have you had trouble staying awake while driving, eating meals, or engaging in social activity?",
        "explanation": "How often you felt excessively sleepy or struggled to stay awake during the day."
    },
    "q9": {
        "question": "Q9: During the past month, how much of a problem has it been for you to keep up enough enthusiasm to get things done?",
        "explanation": "How much sleep problems affected your motivation or enthusiasm for daily activities."
    }
}

def render_psqi_answers(answers: dict) -> str:
    """
    Pretty-print PSQI answers using proper label mappings.
    - Q5a..Q5j, Q7, Q8, Q9 => frequency map (0..3)
    - Q6 => subjective quality map (0..3), NOT frequency
    - Others (Q1, Q2, Q3, Q4, q10*) => raw value
    """
    freq_map = {
        0: "Not during the past month",
        1: "Less than once a week",
        2: "Once or twice a week",
        3: "Three or more times a week",
    }
    quality_map = {
        0: "Very good",
        1: "Fairly good",
        2: "Fairly bad",
        3: "Very bad",
    }

    def fmt_freq(v):
        try:
            return freq_map[int(v)]
        except Exception:
            return str(v)

    def fmt_quality(v):
        try:
            return quality_map[int(v)]
        except Exception:
            return str(v)

    lines = []
    for q, val in answers.items():
        info = PSQI_MAPPING.get(q)
        if not info:
            lines.append(f"{q}: {val}")
            continue

        if q == "q6":
            answer_str = fmt_quality(val)
        elif q.startswith("q5") or q in ["q7", "q8", "q9"]:
            answer_str = fmt_freq(val)
        else:
            answer_str = str(val)

        lines.append(
            f"{info['question']}\n  ➜ Answer: {answer_str}\n  🛈 {info['explanation']}\n"
        )

    return "\n".join(lines)



router = APIRouter()

@router.post("/agent/evaluate_psqi")
def evaluate_psqi_for_today(user_id: str = Depends(get_current_user_id)):
    today_str = date.today().isoformat()
    entry = psqi_collection.find_one({"user_id": user_id, "date": today_str})
    if not entry:
        raise HTTPException(status_code=404, detail="No PSQI entry found for today.")

    answers = entry.get("answers", {})
    total_score = entry.get("total_score")
    sub_scores = entry.get("sub_scores", {})

    # Render the answers in a natural, explainable way for the agent
    rendered_answers = render_psqi_answers(answers)


# --- PSQI Agent prompt 
    prompt = (
    f"You are an expert sleep evaluator using the Pittsburgh Sleep Quality Index (PSQI).\n"
    f"Tone: professional, supportive, concise (mobile app UI).\n\n"
    f"TOOLS AVAILABLE: PSQIKnowledgeBaseSearch, GetUserPSQIEntry\n"
    f"TOOLING RULES (STRICT):\n"
    f"- When you take an Action, it MUST be exactly one of the tool names above (case-sensitive). Do NOT invent actions.\n"
    f"- If you have enough information, do NOT write any 'Action:' lines. Immediately write: 'Final Answer:' and then your response.\n"
    f"- Never write 'Action: None'. Use at most ONE tool. After a tool call, either finish with 'Final Answer:' or, only if absolutely necessary, use at most one more tool.\n"
    f"- If {total_score} and {sub_scores} are already provided, skip GetUserPSQIEntry.\n\n"
    f"PSQI MAPPING (apply exactly):\n"
    f"- Subjective sleep quality  → Q6\n"
    f"- Sleep latency             → Q2 + Q5a\n"
    f"- Sleep duration            → Q4\n"
    f"- Habitual sleep efficiency → Q1, Q3, Q4   (efficiency = total sleep time ÷ time in bed × 100%)\n"
    f"- Sleep disturbances        → Q5b–Q5j\n"
    f"- Use of sleep medication   → Q7\n"
    f"- Daytime dysfunction       → Q8 + Q9\n\n"
    f"SCORING FACTS (concise & accurate):\n"
    f"- 7 components scored 0–3; PSQI global = sum (range 0–21); higher = worse.\n"
    f"- Clinical cut-off: global score >5 suggests poor sleep quality.\n"
    f"- Habitual sleep efficiency rubric: ≥85% → 0; 75–84% → 1; 65–74% → 2; <65% → 3.\n"
    f"- Sleep duration rubric: >7h → 0; 6–7h → 1; 5–6h → 2; <5h → 3.\n"
    f"- Prefer interpreting provided sub-scores; only recompute if they clearly conflict with the mapping above.\n\n"
    f"DATA:\n{rendered_answers}\n\n"
    f"Total PSQI Score: {total_score}\n"
    f"Sub-scores: {sub_scores}\n\n"
    f"RESPONSE FORMAT (exactly these sections):\n"
    f"- Sleep score interpretation\n"
    f"- Weaknesses identified\n"
    f"- Personalized suggestions\n"
    f"- Relevant scientific info\n\n"
    f"GUIDANCE:\n"
    f"- Be specific and actionable. Keep it tight; avoid repeating the raw answers.\n"
    f"- Use PSQIKnowledgeBaseSearch at most once to add 1–2 concise evidence statements.\n"
    f"- If all components are ideal (0) and global is 0–2, you may say: 'Your sleep is excellent!'\n\n"
    f"When you finish, write 'Final Answer:' and then your response only.\n"
    f"OUTPUT TEMPLATE (follow strictly; do not include placeholders/brackets in the final answer):\n"
    f"Final Answer:\n"
    f"\n"
    f"## Sleep score interpretation\n"
    f"PSQI global: <write the number>. Write one exact classification sentence based on the global score:\n"
    f"- If global ≤ 2 → 'Excellent sleep quality (well below the clinical cut-off).'\n"
    f"- If 3–5 → 'Borderline: not classified as poor by PSQI, but close to the clinical cut-off (>5).'\n"
    f"- If ≥ 6 → 'Poor sleep quality by PSQI (global >5).'\n"
    f"Then in one short sentence, summarize the key non-zero components that drive the score (e.g., 'driven mainly by latency and minor disturbances').\n"
    f"\n"
    f"## Weaknesses identified\n"
    f"List at most three bullets, prioritized by component severity (latency > duration > disturbances > subjective quality > others). Each bullet must be one line, specific, and reference the domain and direction (e.g., 'Sleep latency elevated: ~30 min and difficulty falling asleep once–twice/week'). Do not repeat raw questionnaire text.\n"
    f"\n"
    f"## Personalized suggestions\n"
    f"Write 2–4 concise, actionable bullets tailored to the weaknesses. Use the following exact phrasings when applicable:\n"
    f"- If bedtime is later than 01:30 AND total sleep < 7 h → 'Shift lights-out earlier by 30–60 minutes for the next 1–2 weeks.'\n"
    f"- If latency component ≥ 2 or you infer prolonged sleep onset → 'Do a 20–30 minute wind-down (breathing, light reading); avoid screens 60–90 minutes before bed.'\n"
    f"- If disturbances include feeling too hot → 'Keep the bedroom cool and use lighter bedding.'\n"
    f"- Generic but precise hygiene (use at most one of these): 'Keep a consistent sleep–wake schedule (±30 min).', 'No caffeine after 3 pm.'\n"
    f"Avoid generic filler; every bullet must be directly tied to a weakness above.\n"
    f"\n"
    f"## Relevant scientific info\n"
    f"Add 2–3 succinct evidence statements that are already implied by the SCORING FACTS, such as:\n"
    f"- 'PSQI global >5 is a widely used clinical threshold; higher scores indicate worse sleep quality.'\n"
    f"- 'Habitual sleep efficiency ≥85% is generally considered good.'\n"
    f"- 'Most adults benefit from ~7–9 hours of sleep per night; shorter habitual duration is associated with worse daytime functioning.'\n"

)



    try:
        result = run_psqi_agent(prompt, user_id, today_str)
    except RateLimitError as e:
        # Return a clean 429 to the client
        raise HTTPException(status_code=429, detail=f"LLM rate limit: {e}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Agent failed: {e}")

    result = run_psqi_agent(prompt, user_id, today_str)
    print("AGENT RESULT:", result)

    suggestions_str = None

    #  stats, gamification 
    def score_badge(total_score):
        if total_score is not None:
            if total_score < 5:
                return "Sleep Champion"
            elif total_score < 8:
                return "Sleep Improver"
            else:
                return "Needs Attention"
        return "No badge"

    entry_count = psqi_collection.count_documents({"user_id": user_id})
    level = min(1 + entry_count // 10, 5)





    psqi_evaluation_collection.insert_one({
        "user_id": user_id,
        "date": today_str,
        "agent_result": result,
        "psqi_score": total_score,
        "suggestions": suggestions_str,
        "created_at": datetime.utcnow(),
        "badge": score_badge(total_score),
        "level": level
    })

    return {
        "result": result,
        "psqi_score": total_score,
        "badge": score_badge(total_score),
        "level": level,
        "suggestions": suggestions_str
    }

