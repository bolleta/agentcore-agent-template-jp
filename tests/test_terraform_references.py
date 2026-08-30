"""Catch dangling Terraform resource references without running `terraform init`.

This exists because renaming resources during the workshop-to-template refactor
left five `aws_cloudwatch_log_delivery_source` blocks in the observability files
pointing at the pre-rename names (`aws_bedrockagent_knowledge_base.tech_support`,
`aws_bedrockagentcore_memory.customer_support`,
`aws_bedrockagentcore_gateway.customer_support`). `terraform validate` catches it,
but only after a provider download; this runs in milliseconds on every push.
"""

import pytest

from conftest import declared_addresses, referenced_addresses, tf_module_dirs


@pytest.mark.parametrize("module_dir", tf_module_dirs(), ids=lambda p: p.name)
def test_every_referenced_resource_is_declared_in_its_module(module_dir):
    declared = declared_addresses(module_dir)
    dangling = {
        addr: tf.name
        for addr, tf in referenced_addresses(module_dir).items()
        if addr not in declared
    }
    assert not dangling, (
        f"{module_dir}: references to undeclared resources: {dangling}. "
        "A resource was probably renamed without updating every reference."
    )
