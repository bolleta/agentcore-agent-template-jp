resource "aws_iam_role" "gateway" {
  name = "${local.project_name}-agentcore-gw"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock-agentcore.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "gateway" {
  name = "gateway"
  role = aws_iam_role.gateway.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "InvokeLambdaTools"
        Effect = "Allow"
        Action = "lambda:InvokeFunction"
        Resource = [
          aws_lambda_function.tool_read.arn,
          aws_lambda_function.tool_write.arn,
          aws_lambda_function.interceptor.arn,
        ]
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogDelivery",
          "logs:PutLogEvents",
        ]
        Resource = "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/bedrock-agentcore/*"
      },
      {
        Sid    = "XRayTrace"
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
        ]
        Resource = "*"
      },
      {
        Sid    = "AgentCoreGateway"
        Effect = "Allow"
        Action = [
          "bedrock-agentcore:InvokeGateway",
          "bedrock-agentcore:GetGateway",
          "bedrock-agentcore:ListGatewayTargets",
        ]
        Resource = "arn:aws:bedrock-agentcore:${local.region}:${local.account_id}:gateway/*"
      },
      {
        Sid      = "GetApiKey"
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:bedrock-agentcore-identity!default/apikey/*"
      }
    ]
  })
}
