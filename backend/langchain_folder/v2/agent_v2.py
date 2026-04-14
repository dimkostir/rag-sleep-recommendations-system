from langchain.agents import initialize_agent
from .tools import get_user_data_tool, sleep_score_tool, evidence_tool, lifestyle_tool, trends_tool
from langchain_groq import ChatGroq
from dotenv import load_dotenv
import os

from langchain.agents import create_openai_functions_agent, AgentExecutor


load_dotenv()

groq_api_key = os.getenv("GROQ_API_KEY")
groq_model = os.getenv("GROQ_MODEL")

LLM = ChatGroq(
    temperature=0,
    model_name=groq_model,
    groq_api_key=groq_api_key
)

from langchain import hub

prompt = hub.pull("hwchase17/openai-functions-agent")

TOOLS = [
    get_user_data_tool,
    sleep_score_tool,
    lifestyle_tool,
    evidence_tool,
    trends_tool,
]

agent = create_openai_functions_agent(LLM, 
                                      TOOLS, 
                                      prompt)

agent_executor = AgentExecutor(agent=agent,
                               tools=TOOLS, 
                               verbose=True,
                               max_iterations=6, 
                               handle_parsing_errors=True)


def run_sleep_agent(prompt: str, user_id: str, date_str: str):
    full_prompt = f"{prompt}\nuser_id: {user_id}\ndate: {date_str}"
    print("DEBUG FINAL PROMPT:", full_prompt)
    result = agent_executor.invoke({"input": full_prompt})
    return result.get("output", "")
    
