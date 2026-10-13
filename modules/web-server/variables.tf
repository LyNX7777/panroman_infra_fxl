variable "load_balancer_security_group_id" {
  description = "ALB security group allowed to connect to Nginx on port 80."
  type        = string
}

variable "project_name" {
  description = "Project name used for resource names and tags."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC in which to create the web-server security group."
  type        = string
}

variable "subnet_id" {
  description = "ID of the public subnet in which to launch the web server."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the web server."
  type        = string

  validation {
    condition     = length(trimspace(var.instance_type)) > 0
    error_message = "instance_type must not be empty."
  }
}

variable "index_html_content" {
  description = "HTML document served by the Nginx container."
  type        = string

  validation {
    condition     = length(var.index_html_content) > 0
    error_message = "index_html_content must not be empty."
  }
}
