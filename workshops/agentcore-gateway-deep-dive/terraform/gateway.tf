resource "awscc_bedrockagentcore_gateway" "this" {
  name          = local.project_name
  description   = "MCP gateway"
  role_arn      = aws_iam_role.gateway.arn
  protocol_type = "MCP"

  # JWT authorizer — validates Cognito tokens on every request.
  # allowed_scopes: token must contain AT LEAST this scope to pass the JWT check.
  # Fine-grained per-tool access is enforced by Cedar policies (gateway-policies.tf).
  authorizer_type = "CUSTOM_JWT"
  authorizer_configuration = {
    custom_jwt_authorizer = {
      discovery_url = local.cognito_discovery_url
      # =======================================================================
      # EDIT: minimum scope required to reach the gateway.
      # Per-tool restrictions live in gateway-policies.tf Cedar policies.
      # =======================================================================
      allowed_scopes = ["gateway/read"]
    }
  }

  # Cedar Policy Engine — evaluates fine-grained authorization before every tool call.
  # mode = "ENFORCE": blocks denied requests.
  # mode = "LOG_ONLY": logs decisions to CloudWatch without blocking (useful during rollout).
  policy_engine_configuration = {
    arn  = awscc_bedrockagentcore_policy_engine.this.policy_engine_arn
    mode = "ENFORCE"
  }

  # Interceptor Lambda — runs before/after every tool call.
  # Useful for request logging, payload transformation, or custom auth checks.
  # Remove this block entirely if you don't need an interceptor.
  interceptor_configurations = [
    {
      interception_points = ["REQUEST", "RESPONSE"]
      interceptor = {
        lambda = {
          arn = aws_lambda_function.interceptor.arn
        }
      }
      input_configuration = {
        pass_request_headers = true
      }
    }
  ]

  exception_level = "DEBUG"
}

# =============================================================================
# GATEWAY TARGETS — one block per Lambda tool.
# Copy and rename for additional tools; update name, Lambda ARN, and tool_schema.
# Cedar policy name format: "<target-name>___<tool-schema-name>"
# =============================================================================

# Tool 1: read-only lookup (allowed for all authenticated callers via Cedar policy)
resource "aws_bedrockagentcore_gateway_target" "tool_read" {
  name               = "tool-read"
  gateway_identifier = awscc_bedrockagentcore_gateway.this.gateway_identifier

  credential_provider_configuration {
    gateway_iam_role {}
  }

  target_configuration {
    mcp {
      lambda {
        lambda_arn = aws_lambda_function.tool_read.arn

        tool_schema {
          inline_payload {
            # =================================================================
            # EDIT: update name, description, and input_schema for your tool.
            # =================================================================
            name        = "tool-read"
            description = "Read-only lookup. Replace with your tool description."

            input_schema {
              type = "object"
              # Add properties as needed, e.g.:
              # property {
              #   name        = "query"
              #   type        = "string"
              #   description = "Search query"
              #   required    = true
              # }
            }
          }
        }
      }
    }
  }

  depends_on = [aws_lambda_function.tool_read]
}

# Tool 2: write operation (scope-restricted via Cedar policy in gateway-policies.tf)
resource "aws_bedrockagentcore_gateway_target" "tool_write" {
  name               = "tool-write"
  gateway_identifier = awscc_bedrockagentcore_gateway.this.gateway_identifier

  credential_provider_configuration {
    gateway_iam_role {}
  }

  target_configuration {
    mcp {
      lambda {
        lambda_arn = aws_lambda_function.tool_write.arn

        tool_schema {
          inline_payload {
            name        = "tool-write"
            description = "Write operation. Replace with your tool description."

            input_schema {
              type = "object"

              property {
                name        = "input"
                type        = "string"
                description = "Input for the write operation"
                required    = true
              }
            }
          }
        }
      }
    }
  }

  depends_on = [aws_lambda_function.tool_write]
}

resource "local_file" "gateway_url" {
  content  = awscc_bedrockagentcore_gateway.this.gateway_url
  filename = "${path.root}/../tmp/gateway_url.txt"
}

resource "local_file" "gateway_id" {
  content  = awscc_bedrockagentcore_gateway.this.gateway_identifier
  filename = "${path.root}/../tmp/gateway_id.txt"
}

resource "local_file" "gateway_arn" {
  content  = awscc_bedrockagentcore_gateway.this.gateway_arn
  filename = "${path.root}/../tmp/gateway_arn.txt"
}
