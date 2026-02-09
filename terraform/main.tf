terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "personal"
}

locals {
  domain      = "plotwiser.com"
  zone_id     = "Z10152992WETAK9JM7ESY"
  content_dir = "${path.module}/../content"
  mime_types = {
    ".html" = "text/html"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".css"  = "text/css"
    ".js"   = "application/javascript"
    ".json" = "application/json"
    ".svg"  = "image/svg+xml"
    ".ico"  = "image/x-icon"
  }
}

# --- S3 bucket ---

resource "aws_s3_bucket" "site" {
  bucket = local.domain
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Upload content folder
resource "aws_s3_object" "files" {
  for_each = fileset(local.content_dir, "**/*")

  bucket       = aws_s3_bucket.site.id
  key          = each.value
  source       = "${local.content_dir}/${each.value}"
  etag         = filemd5("${local.content_dir}/${each.value}")
  content_type = lookup(local.mime_types, regex("\\.[^.]+$", each.value), "application/octet-stream")
}

# Rename the HTML to index.html at the root
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.site.id
  key          = "index.html"
  source       = "${local.content_dir}/plotwiser_landing.html"
  etag         = filemd5("${local.content_dir}/plotwiser_landing.html")
  content_type = "text/html"
}

# --- ACM certificate ---

resource "aws_acm_certificate" "cert" {
  domain_name               = local.domain
  subject_alternative_names = ["www.${local.domain}"]
  validation_method         = "DNS"

  lifecycle { create_before_destroy = true }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = local.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 300
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# --- CloudFront ---

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${local.domain}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  default_root_object = "index.html"
  aliases             = [local.domain, "www.${local.domain}"]
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    target_origin_id       = "s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cert.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }
}

# S3 bucket policy — allow CloudFront OAC
resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFront"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.site.arn}/*"
      Condition = {
        StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.cdn.arn }
      }
    }]
  })
}

# --- DNS records ---

resource "aws_route53_record" "apex" {
  zone_id = local.zone_id
  name    = local.domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www" {
  zone_id = local.zone_id
  name    = "www.${local.domain}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
    evaluate_target_health = false
  }
}

# --- Outputs ---

output "cloudfront_url" { value = "https://${aws_cloudfront_distribution.cdn.domain_name}" }
output "site_url" { value = "https://${local.domain}" }
