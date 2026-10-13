output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.demo.id
}

output "public_subnet_id" {
  description = "ID of the public subnet."
  value       = aws_subnet.public.id
  depends_on  = [aws_route.internet, aws_route_table_association.public]
}

output "public_subnet_ids" {
  description = "Public subnets in two Availability Zones, ready for the ALB."
  value       = [aws_subnet.public.id, aws_subnet.public_secondary.id]
  depends_on  = [aws_route.internet, aws_route_table_association.public, aws_route_table_association.public_secondary]
}
