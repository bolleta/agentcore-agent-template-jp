resource "aws_iam_role" "gateway" {
  name = "${var.project_name}-agentcore-gw"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock-agentcore.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "gateway_invoke_lambda" {
  role = aws_iam_role.gateway.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "lambda:InvokeFunction"
        # =======================================================================
        # EDIT: add/replace Lambda ARNs when you add or change gateway tools
        # =======================================================================
        Resource = [
          aws_lambda_function.example_tool.arn,
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

# =============================================================================
# INFRASTRUCTURE — no changes needed here unless you rename the gateway
# =============================================================================
resource "aws_bedrockagentcore_gateway" "agent" {
  name            = "${var.project_name}-gw"
  description     = "MCP gateway for agent tools"
  role_arn        = aws_iam_role.gateway.arn
  protocol_type   = "MCP"
  authorizer_type = "CUSTOM_JWT"
  authorizer_configuration {
    custom_jwt_authorizer {
      discovery_url  = local.cognito_discovery_url
      allowed_scopes = [local.cognito_scope]
    }
  }
}

# =============================================================================
# EDIT: define one gateway target per Lambda tool.
# Copy this block to add more tools; update name, description, Lambda ARN,
# tool_schema name/description, and input properties.
# =============================================================================
resource "aws_bedrockagentcore_gateway_target" "example_tool" {
  name               = "example-tool"
  gateway_identifier = aws_bedrockagentcore_gateway.agent.gateway_id
  description        = "Example tool exposed via MCP gateway"

  credential_provider_configuration {
    gateway_iam_role {}
  }

  target_configuration {
    mcp {
      lambda {
        lambda_arn = aws_lambda_function.example_tool.arn

        tool_schema {
          inline_payload {
            name        = "example_tool"
            description = "An example tool. Replace with your tool's description."

            input_schema {
              type = "object"

              property {
                name        = "input"
                type        = "string"
                description = "Input to the tool"
                required    = true
              }
            }
          }
        }
      }
    }
  }
}

resource "local_file" "gateway_url" {
  content  = aws_bedrockagentcore_gateway.agent.gateway_url
  filename = "${path.root}/../tmp/gateway_url.txt"
}

resource "local_file" "gateway_id" {
  content  = aws_bedrockagentcore_gateway.agent.gateway_id
  filename = "${path.root}/../tmp/gateway_id.txt"
}

resource "local_file" "gateway_arn" {
  content  = aws_bedrockagentcore_gateway.agent.gateway_arn
  filename = "${path.root}/../tmp/gateway_arn.txt"
}

output "gateway_url" {
  value = aws_bedrockagentcore_gateway.agent.gateway_url
}

output "gateway_id" {
  value = aws_bedrockagentcore_gateway.agent.gateway_id
}
