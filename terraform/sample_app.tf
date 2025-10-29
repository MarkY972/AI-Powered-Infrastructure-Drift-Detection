# Sample "Hello, World" Lambda Function
resource "aws_lambda_function" "hello_world" {
  filename      = "hello_world.zip"
  function_name = "hello-world"
  role          = aws_iam_role.hello_world_exec_role.arn
  handler       = "hello_world.handler"
  runtime       = "python3.8"
  timeout       = 10
}

# IAM Role for the "Hello, World" Lambda
resource "aws_iam_role" "hello_world_exec_role" {
  name = "hello-world-lambda-exec-role"

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

# API Gateway to trigger the "Hello, World" Lambda
resource "aws_api_gateway_rest_api" "hello_world" {
  name        = "hello-world-api"
  description = "A simple API Gateway for the hello-world Lambda"
}

resource "aws_api_gateway_resource" "hello_world" {
  rest_api_id = aws_api_gateway_rest_api.hello_world.id
  parent_id   = aws_api_gateway_rest_api.hello_world.root_resource_id
  path_part   = "hello"
}

resource "aws_api_gateway_method" "hello_world" {
  rest_api_id   = aws_api_gateway_rest_api.hello_world.id
  resource_id   = aws_api_gateway_resource.hello_world.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "hello_world" {
  rest_api_id = aws_api_gateway_rest_api.hello_world.id
  resource_id = aws_api_gateway_method.hello_world.resource_id
  http_method = aws_api_gateway_method.hello_world.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.hello_world.invoke_arn
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_world.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.hello_world.execution_arn}/*/*"
}
