output "instance_id" {
  description = "ID of the demo EC2 instance."
  value       = module.web_server.instance_id
}

output "alb_dns_name" {
  description = "DNS name of the application load balancer."
  value       = module.load_balancer.dns_name
}

output "application_url" {
  description = "HTTPS URL of the demo application."
  value       = module.dns_certificate.application_url
}

output "target_group_arn" {
  description = "Target group ARN for checking Nginx health."
  value       = module.load_balancer.target_group_arn
}

output "certificate_arn" {
  description = "ARN of the issued ACM certificate used by the HTTPS listener."
  value       = module.dns_certificate.certificate_arn
}
