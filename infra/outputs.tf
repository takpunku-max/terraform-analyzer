output "cloudfront_domain" {
  value = module.cdn.distribution_domain_name
}

output "api_endpoint" {
  value = module.compute.api_endpoint
}

output "ecr_repository_url" {
  value = module.compute.ecr_repository_url
}

