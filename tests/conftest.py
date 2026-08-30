import pathlib
import re
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
AGENT_TEMPLATE = REPO_ROOT / "workshops" / "agentcore-building-ai-agents"
GATEWAY_TEMPLATE = REPO_ROOT / "workshops" / "agentcore-gateway-deep-dive"

# Terraform root modules that must stay internally consistent.
TF_ROOTS = [AGENT_TEMPLATE / "terraform", GATEWAY_TEMPLATE / "terraform"]


def read(path):
    return pathlib.Path(path).read_text(encoding="utf-8")


def strip_comments(hcl):
    """Drop `#` and `//` line comments so commented-out HCL is not parsed."""
    out = []
    for line in hcl.splitlines():
        stripped = line.lstrip()
        if stripped.startswith("#") or stripped.startswith("//"):
            continue
        out.append(line)
    return "\n".join(out)


def load_agent_config():
    """Import agent_config.py without pulling in its runtime dependencies."""
    src = AGENT_TEMPLATE / "src" / "agent"
    sys.path.insert(0, str(src))
    try:
        import agent_config

        return agent_config
    finally:
        sys.path.pop(0)


def tf_module_dirs():
    """Every directory holding .tf files, i.e. every Terraform module."""
    dirs = set()
    for root in TF_ROOTS:
        for tf in root.rglob("*.tf"):
            dirs.add(tf.parent)
    return sorted(dirs)


DECLARED_RE = re.compile(r'^\s*(resource|data)\s+"([\w-]+)"\s+"([\w-]+)"\s*\{', re.M)
# `aws_foo.bar` / `data.aws_foo.bar` used as an expression, not as a declaration.
REFERENCE_RE = re.compile(r'\b(data\.)?(aws_[\w]+)\.([\w-]+)\b')


def declared_addresses(module_dir):
    addrs = set()
    for tf in sorted(module_dir.glob("*.tf")):
        for kind, type_, name in DECLARED_RE.findall(strip_comments(read(tf))):
            prefix = "data." if kind == "data" else ""
            addrs.add(f"{prefix}{type_}.{name}")
    return addrs


def referenced_addresses(module_dir):
    """Resource addresses used in expressions, excluding the declaration headers."""
    refs = {}
    for tf in sorted(module_dir.glob("*.tf")):
        body = strip_comments(read(tf))
        body = DECLARED_RE.sub("", body)  # remove declaration headers
        for is_data, type_, name in REFERENCE_RE.findall(body):
            addr = f"{'data.' if is_data else ''}{type_}.{name}"
            refs.setdefault(addr, tf)
    return refs
