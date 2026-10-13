output "instance_id" {
  description = "ID of the web-server EC2 instance."
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "Stable Elastic IP address of the web server."
  value       = aws_eip.web.public_ip
  depends_on  = [aws_eip_association.web]
}

output "application_url" {
  description = "HTTP URL of the web application."
  value       = "http://${aws_eip.web.public_ip}"
  depends_on  = [aws_eip_association.web]
}
