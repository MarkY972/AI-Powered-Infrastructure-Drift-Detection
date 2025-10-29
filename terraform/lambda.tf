# AWS Lambda Function
resource "aws_lambda_function" "drift_detector" {
  filename      = "drift_detector.zip"
  function_name = "drift-detector"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "drift_detector.handler"
  runtime       = "python3.8"
  timeout       = 300 # Increased timeout for Terraform execution

  layers = [var.terraform_lambda_layer_arn]

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.drift_notifications.arn
    }
  }
}

# IAM Role for Lambda Function
resource "aws_iam_role" "lambda_exec_role" {
  name = "drift-detector-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

# Policy attachment for CloudWatch Logs
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Policy attachment for SNS notifications
resource "aws_iam_role_policy_attachment" "lambda_sns" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess" # Note: For a production system, scope this down.
}

# Policy attachment for Terraform to read infrastructure state
resource "aws_iam_role_policy_attachment" "terraform_readonly" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# CloudWatch Event Rule to trigger the Lambda function
resource "aws_cloudwatch_event_rule" "schedule" {
  name        = "drift-detector-schedule"
  description = "Trigger the drift detector Lambda function on a schedule"
  schedule_expression = "rate(6 hours)"
}

# CloudWatch Event Target to link the rule to the Lambda function
resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.schedule.name
  target_id = "drift-detector-lambda"
  arn       = aws_lambda_function.drift_detector.arn
}

# Lambda permission to allow CloudWatch Events to invoke the function
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.drift_detector.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}
