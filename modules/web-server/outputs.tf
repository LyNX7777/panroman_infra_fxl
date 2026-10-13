output "instance_id" {
  description = "ID of the web-server EC2 instance."
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "Public IPv4 address of the web-server EC2 instance."
  value       = aws_instance.web.public_ip
}

output "application_url" {
  description = "HTTP URL of the web application."
  value       = "http://${aws_instance.web.public_ip}"
}

