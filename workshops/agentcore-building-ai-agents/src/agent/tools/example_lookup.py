from strands.tools import tool
from logger import get_logger

l = get_logger("example_lookup")

# =============================================================================
# EXAMPLE TOOL — replace with your domain-specific logic
# =============================================================================
# Pattern: a @tool function that takes a string input and returns a string.
# The docstring is what the model sees when deciding whether to call this tool.
# In production, replace the mock dict with a real database/API call.

_MOCK_DATA = {
    "example": "This is example data returned by the lookup tool.",
}

@tool
def example_lookup(key: str) -> str:
    """
    Look up information by key.

    Args:
        key: The item to look up

    Returns:
        Information about the requested item, or a not-found message
    """
    result = _MOCK_DATA.get(key.lower())
    if result:
        return result
    return f"No information found for '{key}'. Please try a different query."

l.info("✅ example_lookup tool ready")
