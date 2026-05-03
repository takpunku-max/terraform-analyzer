variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "lambda_image_uri" {
  description = "ECR image URI for the Lambda function"
  type        = string
}

variable "cors_allow_origins" {
  description = "Allowed origins for API Gateway CORS"
  type        = list(string)
}

variable "acm_certificate_arn" {
  description = "ACM wildcard certificate ARN"
  type        = string
}

variable "api_domain_name" {
  description = "Custom domain name for the API (e.g. analyzer-api.kjdevops-portfolio.com)"
  type        = string
}

variable "route53_zone_name" {
  description = "Parent Route53 hosted zone name"
  type        = string
}

