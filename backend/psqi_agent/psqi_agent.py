from langchain.agents import initialize_agent
from psqi_agent.psqi_tools import psqi_data_tool, psqi_kb_tool
from langchain_groq import ChatGroq
from dotenv import load_dotenv
import os

load_dotenv()

groq_api_key = os.getenv("GROQ_API_KEY")
groq_model = os.getenv("GROQ_MODEL")

llm = ChatGroq(
    temperature=0,
    model_name=groq_model,
    groq_api_key=groq_api_key,
    max_tokens=700
)

tools = [psqi_kb_tool, psqi_data_tool]

agent = initialize_agent(
    tools=tools,
    llm=llm,
    agent="zero-shot-react-description",
    handle_parsing_errors=True,
    verbose=True,
    max_iterations=3,
    early_stopping_method="generate"
)

def run_psqi_agent(prompt: str, user_id: str, date_str: str):
    full_prompt = f"{prompt}\nUse the PSQIKnowledgeBaseSearch tool AT MOST ONCE.\nWhen you are done, write 'Final Answer:' then your response.\nuser_id: {user_id}\ndate: {date_str}"
    print("DEBUG FINAL PROMPT:", full_prompt)
    result = agent.invoke({"input": full_prompt})
    return result["output"] if isinstance(result, dict) and "output" in result else result
