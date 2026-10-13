variable "project_name" {
  description = "Project name used for ALB names and tags."
  type        = string
}

variable "vpc_id" {
  description = "VPC containing the ALB and its EC2 target."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs in two different Availability Zones."
  type        = list(string)

  validation {
    condition     = length(distinct(var.public_subnet_ids)) >= 2
    error_message = "At least two distinct public subnets are required."
  }
}

variable "certificate_arn" {
  description = "Validated ACM certificate ARN in the ALB region."
  type        = string
}

variable "instance_id" {
  description = "EC2 instance to register as the HTTP target."
  type        = string
}

variable "web_security_group_id" {
  description = "Web-server security group allowed to receive ALB traffic."
  type        = string
}
