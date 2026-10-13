output "instance_id" {
  description = "ID of the demo EC2 instance."
  value       = module.web_server.instance_id
}

output "public_ip" {
  description = "Public IPv4 address of the demo EC2 instance."
  value       = module.web_server.public_ip
}

output "application_url" {
  description = "HTTP URL of the demo application."
  value       = module.web_server.application_url
}
