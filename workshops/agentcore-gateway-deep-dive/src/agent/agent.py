import asyncio
import os
from strands import Agent
from strands.models import BedrockModel
from system_prompt import SYSTEM_PROMPT
from mcp_client import mcp_tools_list
from logger import get_logger

l = get_logger(__name__)

# =============================================================================
# EDIT: change model_id to your preferred cross-region inference profile.
# Tokyo (ap-northeast-1): "ap.anthropic.claude-sonnet-4-6"
# US default:             "us.anthropic.claude-sonnet-4-6"
# =============================================================================
MODEL_ID = os.environ.get("MODEL_ID", "ap.anthropic.claude-sonnet-4-6")

model = BedrockModel(model_id=MODEL_ID)

agent = Agent(
    model=model,
    system_prompt=SYSTEM_PROMPT,
    tools=[mcp_tools_list],
)

async def run_locally_async():
    print("-" * 40)
    print("AgentCore Gateway Agent")
    print("-" * 40)
    print("Available MCP tools:")
    for tool in mcp_tools_list:
        print(f"  - {tool.tool_name}")
    print("-" * 40)
    while True:
        print()
        # EDIT: change default prompt language as needed
        prompt = input("You (type 'exit' to quit): ").strip()
        if prompt.lower() in ("exit", "quit"):
            break
        if not prompt:
            continue
        async for event in agent.stream_async(prompt):
            tool_use = (
                event.get("event", {})
                .get("contentBlockStart", {})
                .get("start", {})
                .get("toolUse")
            )
            if tool_use:
                print(f"\n[Tool called: {tool_use['name']}]\n")
        print()


if __name__ == "__main__":
    asyncio.run(run_locally_async())
