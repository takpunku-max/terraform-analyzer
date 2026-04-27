terraform{
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 5.0"
        }
    }
}

provider "aws" {
    region = "us-east-1"
}

resource "aws_ecr_repository" "backend" {
    name = "terraform-analyzer-backend"
    image_tag_mutability = "MUTABLE"

    image_scanning_configuration {
        scan_on_push = true
    }
}

resource "aws_iam_role" "lambda_exec" {
    name = "terraform-analyzer-lambda-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
                Service = "lambda.amazonaws.com"
            }
        }]
    })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
    role = aws_iam_role.lambda_exec.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "bedrock_access" {
    name = "bedrock-access"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "aws-marketplace:ViewSubscriptions",
          "aws-marketplace:Subscribe",
          "aws-marketplace:Unsubscribe"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "backend" {
    function_name = "terraform-analyzer-backend"
    role = aws_iam_role.lambda_exec.arn
    package_type = "Image"
    image_uri = "${aws_ecr_repository.backend.repository_url}:latest"
    timeout = 60
    memory_size = 512
}

resource "aws_apigatewayv2_api" "backend" {
    name = "terraform-analyzer-api"
    protocol_type = "HTTP"

    cors_configuration {
        allow_origins = ["*"]
        allow_methods = ["GET", "POST", "OPTIONS"]
        allow_headers = ["content-type"]
    }
}

resource "aws_apigatewayv2_integration" "backend" {
    api_id = aws_apigatewayv2_api.backend.id
    integration_type = "AWS_PROXY"
    integration_uri = aws_lambda_function.backend.invoke_arn
    payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "backend" {
    api_id = aws_apigatewayv2_api.backend.id
    route_key = "ANY /{proxy+}"
    target = "integrations/${aws_apigatewayv2_integration.backend.id}"
}

resource "aws_apigatewayv2_stage" "backend" {
    api_id = aws_apigatewayv2_api.backend.id
    name = "$default"
    auto_deploy = true
}

resource "aws_lambda_permission" "api_gateway" {
    statement_id = "AllowAPIGatewayInvoke"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.backend.function_name
    principal = "apigateway.amazonaws.com"
    source_arn = "${aws_apigatewayv2_api.backend.execution_arn}/*/*"
}

