data "archive_file" "tool_read" {
  type        = "zip"
  source_dir  = "${path.root}/../src/lambdas/tool-read"
  output_path = "${path.root}/../tmp/tool-read.zip"
}

resource "aws_iam_role" "tool_read" {
  name = "${local.project_name}-tool-read"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "tool_read_basic" {
  role       = aws_iam_role.tool_read.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "tool_read" {
  function_name    = "${local.project_name}-tool-read"
  filename         = data.archive_file.tool_read.output_path
  source_code_hash = data.archive_file.tool_read.output_base64sha256
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  memory_size      = 512
  role             = aws_iam_role.tool_read.arn
}
