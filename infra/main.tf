module "storage" {
  source      = "./modules/storage"
  bucket_name = var.bucket_name
}

module "cdn" {
  source = "./modules/cdn"

  bucket_regional_domain_name = module.storage.bucket_regional_domain_name
  oac_id                      = module.storage.oac_id
  domain_name                 = var.domain_name
  acm_certificate_arn         = var.acm_certificate_arn
  route53_zone_name           = var.route53_zone_name
}

module "compute" {
  source = "./modules/compute"

  project_name        = var.project_name
  lambda_image_uri    = var.lambda_image_uri
  acm_certificate_arn = var.acm_certificate_arn
  api_domain_name     = var.api_domain_name
  route53_zone_name   = var.route53_zone_name
  cors_allow_origins  = ["https://${var.domain_name}"]
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = module.storage.bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCloudFrontAccess"
      Effect = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action   = "s3:GetObject"
      Resource = "${module.storage.bucket_arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = module.cdn.distribution_arn
        }
      }
    }]
  })
}

