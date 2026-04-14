from langchain.tools import Tool
from database import psqi_collection
from datetime import datetime
from langchain_community.vectorstores import FAISS
from langchain_huggingface import HuggingFaceEmbeddings
import re

EMB = HuggingFaceEmbeddings(model_name="sentence-transformers/all-MiniLM-L6-v2")
VDB = FAISS.load_local("PSQI_faiss_store", EMB, allow_dangerous_deserialization=True)


# === Tool 1: Retrieve user's sleep data ===
def get_psqi_data(input):
    print("DEBUG user_data_tool input:", input)
    if isinstance(input, dict) and "input" in input:
        input = input["input"]
    if isinstance(input, str):
        match = re.search(r"user_id: *([a-zA-Z0-9]+).*date: *([0-9\-]+)", input, re.DOTALL)
        if match:
            user_id, date = match.groups()
            record = psqi_collection.find_one({"user_id": user_id, "date": date})
            if record:
                    return {"answers": record.get("answers", {}),
                            "total_score": record.get("total_score"),
                            "sub_scores": record.get("sub_scores", {})}                            
            else:
                    return "No PSQI data found."
        else:
            return "user_id/date not found in prompt."
    return "Invalid input for tool."

psqi_data_tool = Tool(
    name="GetUserPSQIEntry",
    func=get_psqi_data,
    description="Get PSQI data for a specific user and date. Pass user_id and date in the prompt as 'user_id: <id>\\ndate: <date>'."
)


# === Tool 2: Knowledge Base===

def psqi_kb_search(query):
    print("DEBUG psqi_kb_search input:", query)
    results = VDB.similarity_search(query, k=2) 
    if not results:
        return "No relevant information found in the PSQI knowledge base."
    # trim long chunks to save tokens
    return "\n\n".join(doc.page_content[:600] for doc in results)

psqi_kb_tool = Tool(
    name="PSQIKnowledgeBaseSearch",
    func=psqi_kb_search,
    description=  ("Search an evidence-based PSQI knowledge base (scoring rubric, component definitions, "
        "clinical cut-off >5, brief sleep-hygiene guidance). Use sparingly for 1–2 concise facts; do not overuse."
)
)
