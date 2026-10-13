output "instance_id" {
  description = "ID of the demo EC2 instance."
  value       = module.web_server.instance_id
}

output "public_ip" {
  description = "Stable Elastic IPv4 address of the demo web server."
  value       = module.web_server.public_ip
}

output "application_url" {
  description = "HTTP URL of the demo application."
  value       = module.dns_certificate.application_url
}

output "direct_application_url" {
  description = "HTTP URL using the Elastic IP directly."
  value       = module.web_server.application_url
}

output "certificate_arn" {
  description = "ARN of the issued ACM certificate reserved for later HTTPS configuration."
  value       = module.dns_certificate.certificate_arn
}
