import os
import boto3
from strands.tools import tool
from strands_tools import retrieve
from logger import get_logger

l = get_logger("knowledge_base")

# Injected by Terraform via the runtime's environment_variables block.
# Set KNOWLEDGE_BASE_ID in your shell for local testing.
KNOWLEDGE_BASE_ID = os.environ.get("KNOWLEDGE_BASE_ID")
l.info(f"ℹ️ KNOWLEDGE_BASE_ID={KNOWLEDGE_BASE_ID}")

@tool
def search_knowledge_base(query: str) -> str:
    """
    Search the knowledge base for information relevant to the query.

    Args:
        query: Natural language description of what to look up

    Returns:
        Relevant passages from the knowledge base, or an error message
    """
    if not KNOWLEDGE_BASE_ID:
        return "Knowledge base is not configured (KNOWLEDGE_BASE_ID not set)."

    try:
        region = boto3.Session().region_name
        tool_use = {
            "toolUseId": "kb_query",
            "input": {
                "text": query,
                "knowledgeBaseId": KNOWLEDGE_BASE_ID,
                "region": region,
                "numberOfResults": 3,
                "score": 0.4,
            },
        }
        result = retrieve.retrieve(tool_use)
        if result["status"] == "success":
            return result["content"][0]["text"]
        return f"Knowledge base query failed: {result['content'][0]['text']}"
    except Exception as e:
        l.error(f"search_knowledge_base error: {e}")
        return f"Knowledge base query failed: {e}"

l.info("✅ search_knowledge_base tool ready")
