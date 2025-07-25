# Add a cloudwatch log group for the lambda function to log its output to
resource "aws_cloudwatch_log_group" "lambda_janitor_log_groups" {
  name = "/aws/lambda/lambda_janitor_function"
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_janitor_lambda_execution_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name = "lambda_janitor_lambda_policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["lambda:DeleteFunction", "lambda:List"]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Bundle up the lambda function code
data "archive_file" "lambda_function_zip" {
  type        = "zip"
  source_dir = "${path.module}/functions"
  output_path = "lambda-janitor-lambda.zip"
}

# Create the lambda function

resource "aws_lambda_function" "lambda_janitor_function" {
  description   = "Lambda function to clean up old, unused versions of Lambda functions"
  function_name = "lambda_janitor_function"
  role          = aws_iam_role.lambda_execution_role.arn
  runtime       = "nodejs22.x"
  filename      = data.archive_file.lambda_function_zip.output_path
  handler       = "clean.handler"
  timeout       = 900

  environment {
    variables = {
      LOG_LEVEL                           = "INFO"
      VERSIONS_TO_KEEP                    = var.versions_to_keep
      AWS_NODEJS_CONNECTION_REUSE_ENABLED = 1
    }
  }
}

# Add a CloudWatch Event Rule to schedule the Lambda function
resource "aws_cloudwatch_event_rule" "clean_scheduled_event" {
  name                = "clean_scheduled_event"
  description         = "Schedule to trigger the Lambda function every hour"
  schedule_expression = "rate(1 hour)"
}

# Add a target for the CloudWatch Event Rule to invoke the Lambda function
resource "aws_cloudwatch_event_target" "lambda_janitor_target" {
  target_id = "lambda_janitor_target"
  rule      = aws_cloudwatch_event_rule.clean_scheduled_event.name
  arn       = aws_lambda_function.lambda_janitor_function.arn
}

# Add permissions to allow the CloudWatch Event Rule to invoke the Lambda function
resource "aws_lambda_permission" "allow_event_rule" {
  statement_id  = "AllowExecutionFromEventRule"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_janitor_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.clean_scheduled_event.arn
}