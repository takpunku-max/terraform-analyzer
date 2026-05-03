variable "bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  type        = string
}

variable "oac_id" {
  description = "Origin access control ID"
  type        = string
}

variable "domain_name" {
  description = "Full subdomain for the frontend (e.g. analyzer.kjdevops-portfolio.com)"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM wildcard certificate ARN"
  type        = string
}

variable "route53_zone_name" {
  description = "Parent Route53 hosted zone name (e.g. kjdevops-portfolio.com)"
  type        = string
}

