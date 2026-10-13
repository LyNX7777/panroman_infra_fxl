variable "aws_account_id" {
  description = "The 12-digit AWS account ID in which resources may be created."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must contain exactly 12 digits."
  }
}

variable "aws_region" {
  description = "AWS region used by the project."
  type        = string
  default     = "eu-central-1"
}

variable "aws_profile" {
  description = "Optional local AWS shared-configuration profile. Leave null in GitHub Actions."
  type        = string
  default     = null
  nullable    = true
}

variable "project_name" {
  description = "Short project name used for resource names and tags."
  type        = string
  default     = "simpleproj1"
}

variable "instance_type" {
  description = "EC2 instance type for the demo web server."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = length(trimspace(var.instance_type)) > 0
    error_message = "instance_type must not be empty."
  }
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the demo VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_cidr" {
  description = "IPv4 CIDR block for the single public subnet."
  type        = string
  default     = "10.0.1.0/24"

  validation {
    condition     = can(cidrnetmask(var.public_subnet_cidr))
    error_message = "public_subnet_cidr must be a valid IPv4 CIDR block."
  }
}

