from langchain.agents import initialize_agent
from .tools import lifestyle_tool, kb_suggestions_tool, sleep_score_tool, user_data_tool
from langchain_groq import ChatGroq
from dotenv import load_dotenv
import os


load_dotenv()

groq_api_key = os.getenv("GROQ_API_KEY")
groq_model = os.getenv("GROQ_MODEL")

LLM = ChatGroq(
    temperature=0,
    model_name=groq_model,
    groq_api_key=groq_api_key
)

TOOLS = [
   lifestyle_tool,
   kb_suggestions_tool,
   sleep_score_tool,
   user_data_tool
]

agent = initialize_agent(
    tools=TOOLS,
    llm=LLM,
    agent="zero-shot-react-description",
    verbose=True,
    handle_parsing_errors=True
)

def run_sleep_agent(prompt: str, user_id: str, date_str: str):
    full_prompt = (
        f"{prompt}\n"
        f"user_id: {user_id}\n"
        f"date: {date_str}"
    )
    print("DEBUG FINAL PROMPT:", full_prompt)
    return agent.run({"input": full_prompt})
