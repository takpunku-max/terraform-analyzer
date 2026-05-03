resource "aws_cloudfront_distribution" "frontend" {
    enabled = true
    default_root_object = "index.html"
    aliases = [var.domain_name]

    origin {
        domain_name = var.bucket_regional_domain_name
        origin_id = "s3-frontend"
        origin_access_control_id = var.oac_id
    }

    default_cache_behavior {
        target_origin_id = "s3-frontend"
        viewer_protocol_policy = "redirect-to-https"
        allowed_methods = ["GET", "HEAD"]
        cached_methods = ["GET", "HEAD"]

    forwarded_values {
        query_string = false
        cookies {forward = "none"}
    }
} 

    restrictions {
        geo_restriction {restriction_type = "none"}
    }

        viewer_certificate {
            acm_certificate_arn = var.acm_certificate_arn
            ssl_support_method = "sni-only"
            minimum_protocol_version = "TLSv1.2_2021"
        }
    }

data "aws_route53_zone" "main" {
  name = var.route53_zone_name
}

resource "aws_route53_record" "frontend" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = false
  }
}

