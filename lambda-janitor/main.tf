#   AWS::ServerlessRepo::Application:
#     Name: lambda-janitor
#     Description: Cron job for deleting old, unused versions of Lambda functions to clean up storage space
#     Author: Lumigo
#     SpdxLicenseId: MIT
#     LicenseUrl: LICENSE.txt
#     ReadmeUrl: README.md
#     Labels: ['lambda', 'cron']
#     HomePageUrl: https://github.com/lumigo/SAR-Lambda-Janitor
#     SemanticVersion: 1.7.0
#     SourceCodeUrl: https://github.com/lumigo/SAR-Lambda-Janitor

#   LogGroup:
#     Type: AWS::Logs::LogGroup
#     Properties:
#       LogGroupName: !Sub /aws/lambda/${Clean}

# Add a cloudwatch log group for the lambda function to log its output to
resource "aws_cloudwatch_log_group" "lambda_janitor_log_groups" {
  name = "/aws/lambda/lambda_janitor_log_groups"
}

# Create the following resources:
# IAM Role for the lambda function to assume
# IAM policy for the lambda function (with the necessary permissions)
# IAM role policy attachment to attach the policy to the role
# And then finally a lambda!

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
  source_dir  = "${path.module}/functions"
  output_path = "lambdaFunction.zip"
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

#   Events:
# CleanScheduledEvent:
#           Type: Schedule
#           Properties:
#             Schedule: rate(1 hour)