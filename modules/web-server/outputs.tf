output "instance_id" {
  description = "ID of the web-server EC2 instance."
  value       = aws_instance.web.id
}

output "security_group_id" {
  description = "Security group identifying the Nginx instance."
  value       = aws_security_group.web.id
}
