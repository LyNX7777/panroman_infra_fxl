output "security_group_id" {
  description = "ALB security group permitted to access Nginx."
  value       = aws_security_group.alb.id
}

output "dns_name" {
  description = "ALB DNS name after listeners, target registration, and ALB rules exist."
  value       = aws_lb.application.dns_name
  depends_on = [
    aws_lb_listener.https,
    aws_lb_listener.http,
    aws_lb_target_group_attachment.nginx,
    aws_vpc_security_group_ingress_rule.public,
    aws_vpc_security_group_egress_rule.nginx,
  ]
}

output "zone_id" {
  description = "Canonical hosted zone ID for the Route 53 ALB alias."
  value       = aws_lb.application.zone_id
}

output "target_group_arn" {
  description = "Target group ARN for inspecting Nginx health."
  value       = aws_lb_target_group.nginx.arn
}
