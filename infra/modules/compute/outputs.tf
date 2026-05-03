output "api_endpoint" {
  value = aws_apigatewayv2_stage.backend.invoke_url
}

output "api_domain_name" {
  value = aws_apigatewayv2_domain_name.backend.domain_name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "lambda_function_name" {
  value = aws_lambda_function.backend.function_name
}

