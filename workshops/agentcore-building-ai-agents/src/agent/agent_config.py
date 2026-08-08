# =============================================================================
# AGENT CONFIGURATION — edit this file when creating a new agent
# =============================================================================

# Display name used in local REPL banners
AGENT_NAME = "My Agent"

# Bedrock cross-region inference profile ID.
# ap-northeast-1 (Tokyo) uses the "ap." prefix.
# If deploying in us-east-1, change to "us.anthropic.claude-sonnet-4-6".
MODEL_ID = "ap.anthropic.claude-sonnet-4-6"

# Memory namespace prefix (must match terraform/memory/memory.tf namespaces)
# Format: "<namespace_prefix>/{actorId}/semantic/" and "...preferences/"
MEMORY_NAMESPACE_PREFIX = "support/customer"

# Actor ID injected into memory namespaces at runtime.
# In production, derive this from the authenticated user identity.
DEFAULT_ACTOR_ID = "user-001"
