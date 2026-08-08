import opentelemetry.instrumentation.auto_instrumentation

from bedrock_agentcore.runtime import BedrockAgentCoreApp
from strands import Agent
from strands.models import BedrockModel
from system_prompt import SYSTEM_PROMPT
from memory_config import get_session_manager
from agent_config import AGENT_NAME, MODEL_ID
import asyncio
import uuid
from logger import get_logger
from mcp_client import mcp_tools_list
import os

# =============================================================================
# TOOLS — replace or extend with your own @tool functions
# =============================================================================
from tools.example_lookup import example_lookup
from tools.knowledge_base import search_knowledge_base

l = get_logger(__name__)

model = BedrockModel(model_id=MODEL_ID)

# Add / remove tools here. mcp_tools_list wires in gateway tools automatically.
tools = [
    example_lookup,
    search_knowledge_base,
    *mcp_tools_list,
]

app = BedrockAgentCoreApp()
@app.entrypoint
async def invoke(payload, _context=None):
    # Generate a new session_id per request so each invocation gets its own
    # memory window. A module-level id would share memory across all callers.
    session_id = str(uuid.uuid4())
    user_prompt = payload.get("prompt", "こんにちは！")

    l.info(f"ℹ️ user_prompt={user_prompt}")

    session_manager = get_session_manager(session_id)

    agent = Agent(
        model=model,
        system_prompt=SYSTEM_PROMPT,
        tools=tools,
        session_manager=session_manager,
        callback_handler=None,
    )

    async for event in agent.stream_async(user_prompt):
        tool_use = event.get("event", {}).get("contentBlockStart", {}).get("start", {}).get("toolUse")
        if tool_use:
            print(f"\n[Tool called: {tool_use['name']}]\n")

        text_chunk = event.get("data")
        if text_chunk:
            yield text_chunk

async def run_locally_async():
    print("-" * 20)
    print(f"Welcome to {AGENT_NAME} (local)")
    while True:
        print("\n" + "-" * 20)
        prompt = input("User prompt (type 'exit' to quit): ").strip()
        if prompt.lower() == "exit":
            break
        if not prompt:
            continue
        async for text_chunk in invoke({"prompt": prompt}):
            print(text_chunk, end="", flush=True)
        print()

if __name__ == "__main__":
    if os.environ.get("AGENTCORE_RUNTIME_URL"):
        print("Initializing OTEL...")
        opentelemetry.instrumentation.auto_instrumentation.initialize()

        print("Running on AgentCore, starting server...")
        app.run()
    else:
        print("Running locally...")
        asyncio.run(run_locally_async())

