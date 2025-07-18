# We need the following
# A lambda running node 18 which takes the variable RETENTION_DAYS

# lambda provisioned, with the following policies
# can PutRetentionPolicy on everything *
# the event it subscribes to is cloudwatchevent of pattern aws.logs, createloggroup

# and another serverless function which sets retention for existing log groups
# this will happen on load meaning timeout is 900
# it has action PutRetentionPolicy and DescribeLogGroup on everything *
# 

# Add a cloudwatch log group for the new log groups lambda & the existing log groups lambda
# This in turn will be used to log the output of the lambda functions
resource "aws_cloudwatch_log_group" "set_retention_for_new_log_groups" {
  name = "/aws/lambda/set_retention_for_new_log_groups"
}

resource "aws_cloudwatch_log_group" "set_retention_for_existing_log_groups" {
  name = "/aws/lambda/set_retention_for_existing_log_groups"
}

# Create the iam role, allowing the lambda to assume the role
# Create iam policy, allowing the lambda to put retention policy and describe log groups
# Attach the policy to the role
resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"
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
  name = "lambda_policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["logs:PutRetentionPolicy", "logs:DescribeLogGroups"]
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
  source_file = "${path.module}/functions/hello-world.js"
  output_path = "lambdaFunction.zip"
}

# Create the lambda functions for setting retention policies
# One for new log groups and one for existing log groups
resource "aws_lambda_function" "set_retention_for_new_log_groups_function" {
  description   = "Updates the retention policy for a newly created CloudWatch log group to the specified number of days."
  function_name = "set_retention_for_new_log_groups"
  role          = aws_iam_role.lambda_execution_role.arn
  runtime       = "nodejs22.x"
  filename      = data.archive_file.lambda_function_zip.output_path
  handler       = "hello-world.newLogGroups"
  memory_size   = 128
  timeout       = 6

  environment {
    variables = {
      RETENTION_DAYS = var.retention_days
    }
  }
}

resource "aws_lambda_function" "set_retention_for_existing_log_groups_function" {
  description   = "Updates the retention policy for existing log groups to match the configured number of days."
  function_name = "set_retention_for_existing_log_groups"
  role          = aws_iam_role.lambda_execution_role.arn
  runtime       = "nodejs22.x"
  filename      = data.archive_file.lambda_function_zip.output_path
  handler       = "hello-world.existingLogGroups"
  memory_size   = 128
  timeout       = 900

  environment {
    variables = {
      RETENTION_DAYS = var.retention_days
    }
  }
}

# Create a CloudWatch event rule to trigger the new log groups lambda function
# We also create event targets to link the rule to the lambda function
# Then we add permissions to allow the event rule to invoke the lambda function
resource "aws_cloudwatch_event_rule" "new_log_groups_rule" {
  name        = "new_log_groups_rule"
  description = "Trigger for new log groups"
  event_pattern = jsonencode({
    source      = ["aws.logs"],
    detail_type = ["AWS Console Sign-in via CloudTrail"],
    detail = {
      eventSource = ["logs.amazonaws.com"],
      eventName   = ["CreateLogGroup"]
    }
  })
}

resource "aws_cloudwatch_event_target" "new_log_groups_target" {
  target_id = "new-log-groups-target"
  rule      = aws_cloudwatch_event_rule.new_log_groups_rule.name
  arn       = aws_lambda_function.set_retention_for_new_log_groups_function.arn
}

resource "aws_lambda_permission" "allow_event_rule" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.set_retention_for_new_log_groups_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.new_log_groups_rule.arn
}

# Need to handle existing log groups - this will run on terraform apply
resource "aws_cloudwatch_event_rule" "existing_log_groups_rule" {
  name        = "existing_log_groups_rule"
  description = "Trigger for existing log groups - On terraform apply"
  event_pattern = jsonencode({
    source      = ["aws.terraform"],
    detail_type = ["Terraform Apply"],
  })
}

resource "aws_cloudwatch_event_target" "existing_log_groups_target" {
  target_id = "existing-log-groups-target"
  rule      = aws_cloudwatch_event_rule.existing_log_groups_rule.name
  arn       = aws_lambda_function.set_retention_for_existing_log_groups_function.arn
}

resource "aws_lambda_permission" "allow_existing_event_rule" {
  statement_id  = "AllowExecutionFromExistingCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.set_retention_for_existing_log_groups_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.existing_log_groups_rule.arn
}