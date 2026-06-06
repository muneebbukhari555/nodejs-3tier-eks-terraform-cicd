output "domain_name" {
  value = try(aws_cloudfront_distribution.web[0].domain_name, "")
}
