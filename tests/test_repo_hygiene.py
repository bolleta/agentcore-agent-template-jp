"""Cheap checks that keep the repository safe to publish."""

import re

from conftest import REPO_ROOT, read, tf_module_dirs

REQUIRED_IGNORES = [".env", "terraform.tfstate", ".terraform/", "*.pem", "*.key"]

# Placeholders that upstream documentation uses on purpose.
PLACEHOLDER_ACCOUNT_IDS = {"123456789012", "123123123123", "000000000000"}


def test_gitignore_covers_state_and_credentials():
    body = read(REPO_ROOT / ".gitignore")
    missing = [pattern for pattern in REQUIRED_IGNORES if pattern not in body]
    assert not missing, f".gitignore is missing: {missing}"


def test_no_real_aws_account_ids_are_committed():
    offenders = {}
    for path in REPO_ROOT.rglob("*"):
        if not path.is_file() or ".git/" in str(path) or path.suffix in {".png", ".lock"}:
            continue
        try:
            body = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        found = {
            n for n in re.findall(r"\b\d{12}\b", body) if n not in PLACEHOLDER_ACCOUNT_IDS
        }
        if found:
            offenders[str(path.relative_to(REPO_ROOT))] = sorted(found)
    assert not offenders, f"possible real AWS account IDs committed: {offenders}"


def test_every_terraform_module_pins_its_variables():
    """Each child module declares its inputs, so `terraform validate` is meaningful."""
    for module_dir in tf_module_dirs():
        if module_dir.name == "terraform":  # root modules take no inputs
            continue
        assert (module_dir / "variables.tf").exists(), (
            f"{module_dir} has no variables.tf"
        )
