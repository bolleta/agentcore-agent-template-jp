"""Guard the settings that must agree across Python and Terraform.

These pairings are easy to break because they live in different files and
different languages, and nothing fails until an actual deploy.
"""

import re

from conftest import AGENT_TEMPLATE, load_agent_config, read, strip_comments

TF = AGENT_TEMPLATE / "terraform"

# Bedrock cross-region inference profiles are prefixed by geography.
REGION_TO_PROFILE_PREFIX = {"ap-": "ap.", "us-": "us.", "eu-": "eu."}


def provider_region():
    body = strip_comments(read(TF / "providers.tf"))
    match = re.search(r'provider\s+"aws"\s*\{[^}]*region\s*=\s*"([\w-]+)"', body, re.S)
    assert match, "providers.tf must pin an explicit aws provider region"
    return match.group(1)


def test_model_id_prefix_matches_provider_region():
    """`ap.` profiles do not resolve from a us-east-1 provider, and vice versa."""
    region = provider_region()
    expected = next(
        prefix for geo, prefix in REGION_TO_PROFILE_PREFIX.items() if region.startswith(geo)
    )
    model_id = load_agent_config().MODEL_ID
    assert model_id.startswith(expected), (
        f"providers.tf deploys to {region}, so MODEL_ID should start with "
        f"{expected!r}, got {model_id!r}"
    )


def test_embedding_model_matches_the_one_the_kb_role_may_invoke():
    """The KB IAM policy grants InvokeModel on exactly one embedding model ARN."""
    body = strip_comments(read(TF / "knowledge_base" / "kb.tf"))
    used = set(re.findall(r"foundation-model/([\w.:-]+)", body))
    assert len(used) == 1, (
        f"kb.tf names more than one foundation model ({used}); the IAM policy "
        "and the knowledge base configuration must reference the same one"
    )


def test_memory_namespace_prefix_matches_terraform_strategies():
    """Namespaces are matched as literal strings; a mismatch silently loses memory."""
    prefix = load_agent_config().MEMORY_NAMESPACE_PREFIX
    body = strip_comments(read(TF / "memory" / "memory.tf"))
    namespaces = re.findall(r'namespaces\s*=\s*\["([^"]+)"\]', body)
    assert namespaces, "memory.tf declares no strategy namespaces"
    for namespace in namespaces:
        assert namespace.startswith(prefix + "/"), (
            f"memory.tf namespace {namespace!r} does not start with "
            f"MEMORY_NAMESPACE_PREFIX {prefix!r} from agent_config.py"
        )


def test_runtime_role_grants_no_bedrock_wildcards():
    """The upstream role carried bedrock:* / bedrock-agentcore:*; keep it narrow."""
    body = strip_comments(read(TF / "runtime" / "runtime.tf"))
    wildcards = re.findall(r'"((?:bedrock|bedrock-agentcore|aws-marketplace):\*)"', body)
    assert not wildcards, f"runtime.tf grants wildcard actions: {wildcards}"
