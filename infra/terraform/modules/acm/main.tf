# ---------------------------------------------------------------------------
# ACM certificates for the app domain, DNS-validated in Route 53.
#
# TWO certs for ONE domain, because of where each AWS service reads certs:
#   - ALB  cert: must be in the ALB's region (us-east-2)  -> default `aws`
#   - CloudFront cert: MUST be in us-east-1 (CloudFront is a global service
#     whose control plane lives there) -> `aws.cloudfront` aliased provider
#
# All disabled when domain_name = "" (count = 0).
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.cloudfront]
    }
  }
}

locals {
  enabled = var.domain_name == "" ? 0 : 1
}

# ---- ALB certificate (same region as the ALB) ----
resource "aws_acm_certificate" "alb" {
  count             = local.enabled
  domain_name       = var.domain_name
  validation_method = "DNS"
  tags              = var.tags
  lifecycle { create_before_destroy = true }
}

resource "aws_route53_record" "alb_validation" {
  for_each = local.enabled == 0 ? {} : {
    for dvo in aws_acm_certificate.alb[0].domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }
  zone_id = var.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "alb" {
  count                   = local.enabled
  certificate_arn         = aws_acm_certificate.alb[0].arn
  validation_record_fqdns = [for r in aws_route53_record.alb_validation : r.fqdn]
}

# ---- CloudFront certificate (us-east-1, via aliased provider) ----
resource "aws_acm_certificate" "cloudfront" {
  provider          = aws.cloudfront
  count             = local.enabled
  domain_name       = var.domain_name
  validation_method = "DNS"
  tags              = var.tags
  lifecycle { create_before_destroy = true }
}

resource "aws_route53_record" "cf_validation" {
  for_each = local.enabled == 0 ? {} : {
    for dvo in aws_acm_certificate.cloudfront[0].domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }
  zone_id = var.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cloudfront" {
  provider                = aws.cloudfront
  count                   = local.enabled
  certificate_arn         = aws_acm_certificate.cloudfront[0].arn
  validation_record_fqdns = [for r in aws_route53_record.cf_validation : r.fqdn]
}
