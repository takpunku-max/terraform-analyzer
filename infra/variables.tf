variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "terraform-analyzer"
}

variable "bucket_name" {
  description = "S3 frontend bucket name"
  type        = string
  default     = "terraform-analyzer-frontend"
}

variable "domain_name" {
  description = "Frontend subdomain"
  type        = string
  default     = "analyzer.kjdevops-portfolio.com"
}

variable "api_domain_name" {
  description = "API subdomain"
  type        = string
  default     = "analyzer-api.kjdevops-portfolio.com"
}

variable "route53_zone_name" {
  description = "Parent Route53 hosted zone"
  type        = string
  default     = "kjdevops-portfolio.com"
}

variable "acm_certificate_arn" {
  description = "ACM wildcard certificate ARN"
  type        = string
  default     = "arn:aws:acm:us-east-1:895112955219:certificate/4c09310c-23fd-4f39-b674-11a0b84c1fbf"
}

variable "lambda_image_uri" {
  description = "ECR image URI for Lambda"
  type        = string
  default     = "895112955219.dkr.ecr.us-east-1.amazonaws.com/terraform-analyzer-backend:latest"
}

