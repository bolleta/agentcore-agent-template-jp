import os
from bedrock_agentcore.memory.integrations.strands.config import AgentCoreMemoryConfig, RetrievalConfig
from bedrock_agentcore.memory.integrations.strands.session_manager import AgentCoreMemorySessionManager
from agent_config import MEMORY_NAMESPACE_PREFIX, DEFAULT_ACTOR_ID
from logger import get_logger

l = get_logger("memory_config")

MEMORY_ID = os.environ.get("MEMORY_ID")
l.info(f"ℹ️ MEMORY_ID={MEMORY_ID}")

# In production, derive ACTOR_ID from the authenticated user identity.
ACTOR_ID = os.environ.get("ACTOR_ID", DEFAULT_ACTOR_ID)

def get_session_manager(session_id):
    if not MEMORY_ID:
        l.info("⚠️ MEMORY_ID not set, session_manager disabled")
        return None

    # Namespace paths must match terraform/memory/memory.tf strategy namespaces.
    prefix = MEMORY_NAMESPACE_PREFIX
    memory_config = AgentCoreMemoryConfig(
        memory_id=MEMORY_ID,
        batch_size=1,
        flush_interval_seconds=1,
        session_id=session_id,
        actor_id=ACTOR_ID,
        retrieval_config={
            f"{prefix}/{{actorId}}/semantic/":     RetrievalConfig(top_k=3, relevance_score=0.2),
            f"{prefix}/{{actorId}}/preferences/":  RetrievalConfig(top_k=3, relevance_score=0.2),
        }
    )
    session_manager = AgentCoreMemorySessionManager(memory_config)
    l.info(f"✅ session_manager ready (MEMORY_ID={MEMORY_ID})")
    return session_manager


