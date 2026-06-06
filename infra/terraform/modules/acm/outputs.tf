output "alb_certificate_arn" {
  description = "ACM cert ARN for the ALB (us-east-2); empty when no domain"
  value       = try(aws_acm_certificate_validation.alb[0].certificate_arn, "")
}

output "cloudfront_certificate_arn" {
  description = "ACM cert ARN for CloudFront (us-east-1); empty when no domain"
  value       = try(aws_acm_certificate_validation.cloudfront[0].certificate_arn, "")
}
