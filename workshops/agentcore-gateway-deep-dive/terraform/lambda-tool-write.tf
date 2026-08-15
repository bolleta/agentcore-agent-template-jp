data "archive_file" "tool_write" {
  type        = "zip"
  source_dir  = "${path.root}/../src/lambdas/tool-write"
  output_path = "${path.root}/../tmp/tool-write.zip"
}

resource "aws_iam_role" "tool_write" {
  name = "${local.project_name}-tool-write"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "tool_write_basic" {
  role       = aws_iam_role.tool_write.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "tool_write" {
  function_name    = "${local.project_name}-tool-write"
  filename         = data.archive_file.tool_write.output_path
  source_code_hash = data.archive_file.tool_write.output_base64sha256
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  memory_size      = 512
  role             = aws_iam_role.tool_write.arn
}
