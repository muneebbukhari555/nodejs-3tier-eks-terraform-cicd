# CloudFront in front of the web ALB. Created only when alb_dns_name is set
# (Phase 2, after the Ingress provisions the ALB).

resource "aws_cloudfront_distribution" "web" {
  count   = var.alb_dns_name == "" ? 0 : 1
  enabled = true
  comment = "${var.name} web CDN"
  aliases = var.aliases

  origin {
    domain_name = var.alb_dns_name
    origin_id   = "web-alb"
    custom_origin_config {
      http_port  = 80
      https_port = 443
      # If the ALB has its own ACM cert, use https-only end-to-end; otherwise
      # http-only to the origin. (Set when a domain/cert is configured.)
      origin_protocol_policy = var.viewer_certificate_arn == "" ? "http-only" : "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "web-alb"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    forwarded_values {
      query_string = true
      cookies { forward = "all" }
    }
    min_ttl     = 0
    default_ttl = 60
    max_ttl     = 3600
  }

  price_class = var.price_class
  restrictions {
    geo_restriction { restriction_type = "none" }
  }
  viewer_certificate {
    # Custom ACM cert (us-east-1) when a domain is configured; otherwise the
    # default *.cloudfront.net certificate.
    cloudfront_default_certificate = var.viewer_certificate_arn == ""
    acm_certificate_arn            = var.viewer_certificate_arn == "" ? null : var.viewer_certificate_arn
    ssl_support_method             = var.viewer_certificate_arn == "" ? null : "sni-only"
    minimum_protocol_version       = var.viewer_certificate_arn == "" ? null : "TLSv1.2_2021"
  }
  tags = var.tags
}
