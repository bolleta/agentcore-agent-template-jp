resource "awscc_bedrockagentcore_policy_engine" "this" {
  name = local.project_name_underscore
}

# =============================================================================
# Cedar policies — evaluated by the Policy Engine before every tool call.
#
# Action format: AgentCore::Action::"<target-name>___<tool-schema-name>"
#   target-name     = aws_bedrockagentcore_gateway_target.X.name  (e.g. "tool-read")
#   tool-schema-name = inline_payload.name                         (e.g. "tool-read")
#
# To add a new tool: copy one of the blocks below, update the action string,
# and add a scope condition if the tool should be restricted.
# =============================================================================

# Permit tool-read for all authenticated callers (JWT check already passed at gateway level).
resource "awscc_bedrockagentcore_policy" "allow_tool_read" {
  name             = "allow_tool_read"
  policy_engine_id = awscc_bedrockagentcore_policy_engine.this.policy_engine_id
  validation_mode  = "IGNORE_ALL_FINDINGS"

  definition = {
    cedar = {
      statement = <<-EOT
        permit(
          principal,
          action == AgentCore::Action::"tool-read___tool-read",
          resource == AgentCore::Gateway::"${awscc_bedrockagentcore_gateway.this.gateway_arn}"
        );
      EOT
    }
  }

  depends_on = [aws_bedrockagentcore_gateway_target.tool_read]
}

# Permit tool-write only if the token carries the gateway/write scope.
resource "awscc_bedrockagentcore_policy" "allow_tool_write" {
  name             = "allow_tool_write"
  policy_engine_id = awscc_bedrockagentcore_policy_engine.this.policy_engine_id
  validation_mode  = "IGNORE_ALL_FINDINGS"

  definition = {
    cedar = {
      statement = <<-EOT
        permit(
          principal,
          action == AgentCore::Action::"tool-write___tool-write",
          resource == AgentCore::Gateway::"${awscc_bedrockagentcore_gateway.this.gateway_arn}"
        )
        when {
          principal.hasTag("scope") &&
          principal.getTag("scope") like "*gateway/write*"
        };
      EOT
    }
  }

  depends_on = [aws_bedrockagentcore_gateway_target.tool_write]
}

# =============================================================================
# EDIT: Add forbid rules for input-level restrictions, e.g.:
#
# resource "awscc_bedrockagentcore_policy" "forbid_example" {
#   name             = "forbid_example"
#   policy_engine_id = awscc_bedrockagentcore_policy_engine.this.policy_engine_id
#   validation_mode  = "IGNORE_ALL_FINDINGS"
#
#   definition = {
#     cedar = {
#       statement = <<-EOT
#         forbid(
#           principal,
#           action == AgentCore::Action::"tool-write___tool-write",
#           resource == AgentCore::Gateway::"${awscc_bedrockagentcore_gateway.this.gateway_arn}"
#         )
#         when {
#           context.input.someField == "blocked_value"
#         };
#       EOT
#     }
#   }
#   depends_on = [aws_bedrockagentcore_gateway_target.tool_write]
# }
# =============================================================================
