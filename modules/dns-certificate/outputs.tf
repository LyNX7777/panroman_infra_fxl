output "application_url" {
  description = "HTTPS URL published in the existing hosted zone."
  value       = "https://${trimsuffix(aws_route53_record.application.fqdn, ".")}"
}

output "certificate_arn" {
  description = "ARN of the issued, DNS-validated ACM certificate for the ALB."
  value       = aws_acm_certificate_validation.application.certificate_arn
}
