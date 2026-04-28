variable "acm_certificate_arn" {
    description = "ARN of the ACM certificate for the custom domain"
    type        = string
}

terraform {
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
        Resource = "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-haiku-4-5-20251001-v1:0"
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

resource "aws_s3_bucket" "frontend" {
    bucket = "terraform-analyzer-frontend"
}

resource "aws_cloudfront_origin_access_control" "frontend" {
    name = "terraform-analyzer-oac"
    origin_access_control_origin_type = "s3"
    signing_behavior = "always"
    signing_protocol = "sigv4"
}

resource "aws_cloudfront_distribution" "frontend" {
    enabled = true
    default_root_object = "index.html"

    origin {
        domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
        origin_id = "s3-frontend"
        origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
    }

    default_cache_behavior {
        target_origin_id = "s3-frontend"
        viewer_protocol_policy = "redirect-to-https"
        allowed_methods = ["GET", "HEAD"]
        cached_methods = ["GET", "HEAD"]

        forwarded_values {
            query_string = false 
            cookies {
                forward = "none"
            }
        }
    }

    restrictions { 
        geo_restriction {
            restriction_type = "none"
        }
    }

    viewer_certificate {
        cloudfront_default_certificate = true
    }
}

resource "aws_s3_bucket_policy" "frontend" {
    bucket = aws_s3_bucket.frontend.id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Sid = "AllowCloudFrontAccess"
            Effect = "Allow"
            Principal = {
                Service = "cloudfront.amazonaws.com"
            }
            Action = "s3:GetObject"
            Resource = "${aws_s3_bucket.frontend.arn}/*"
            Condition = {
                StringEquals = {
                    "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
                }
            }
        }]
    })
}

data "aws_acm_certificate" "wildcard" {
  domain   = "*.kjdevops-portfolio.com"
  statuses = ["ISSUED"]
}

resource "aws_apigatewayv2_domain_name" "backend" {
    domain_name = "analyzer.kjdevops-portfolio.com"

    domain_name_configuration {
        certificate_arn = data.aws_acm_certificate.wildcard.arn
        endpoint_type = "REGIONAL"
        security_policy = "TLS_1_2"
    }
}

resource "aws_apigatewayv2_api_mapping" "backend" {
    api_id = aws_apigatewayv2_api.backend.id
    domain_name = aws_apigatewayv2_domain_name.backend.id
    stage = aws_apigatewayv2_stage.backend.id
}

data "aws_route53_zone" "main" {
    name = "kjdevops-portfolio.com"
}

resource "aws_route53_record" "analyzer_api" {
    zone_id = data.aws_route53_zone.main.zone_id
    name = "analyzer.kjdevops-portfolio.com"
    type = "A"

    alias {
        name = aws_apigatewayv2_domain_name.backend.domain_name_configuration[0].target_domain_name
        zone_id = aws_apigatewayv2_domain_name.backend.domain_name_configuration[0].hosted_zone_id
        evaluate_target_health = false
    }
}