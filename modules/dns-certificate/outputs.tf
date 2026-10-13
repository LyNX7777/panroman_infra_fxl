output "application_url" {
  description = "HTTP URL published in the existing hosted zone."
  value       = "http://${trimsuffix(aws_route53_record.application.fqdn, ".")}"
}

output "certificate_arn" {
  description = "ARN of the issued, DNS-validated ACM certificate; HTTPS is not configured."
  value       = aws_acm_certificate_validation.application.certificate_arn
}
