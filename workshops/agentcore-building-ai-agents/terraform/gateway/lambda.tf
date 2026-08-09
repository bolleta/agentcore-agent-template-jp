# INFRASTRUCTURE — shared execution role for all gateway Lambda tools
resource "aws_iam_role" "gateway_lambda" {
  name = "${var.project_name}-gw-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "gateway_lambda_basic" {
  role       = aws_iam_role.gateway_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# =============================================================================
# EDIT: one block per Lambda tool. Copy and rename for additional tools.
# Source directory: src/lambdas/<tool-name>/handler.py
# =============================================================================

data "archive_file" "example_tool" {
  type        = "zip"
  source_dir  = "${path.root}/../src/lambdas/example-tool"
  output_path = "${path.root}/../tmp/example-tool.zip"
}

resource "aws_lambda_function" "example_tool" {
  function_name    = "${var.project_name}-example-tool"
  architectures    = ["arm64"]
  filename         = data.archive_file.example_tool.output_path
  source_code_hash = data.archive_file.example_tool.output_base64sha256
  role             = aws_iam_role.gateway_lambda.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.13"
  timeout          = 10
  memory_size      = 512
}

resource "aws_lambda_permission" "gateway_invoke_example_tool" {
  statement_id  = "AllowBedrockAgentCoreGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.example_tool.function_name
  principal     = "bedrock-agentcore.amazonaws.com"
  source_arn    = aws_bedrockagentcore_gateway.agent.gateway_arn
}
