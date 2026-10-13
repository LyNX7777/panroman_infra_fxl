variable "project_name" {
  description = "Project name used for IAM role and policy names."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the deployment role, in owner/repository form."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must use the owner/repository format."
  }
}

variable "github_repository_ids" {
  description = "Immutable GitHub owner and repository IDs for the newer OIDC subject format. Leave null only for repositories using the legacy name-only format."
  type = object({
    owner_id      = string
    repository_id = string
  })
  default = null

  validation {
    condition = var.github_repository_ids == null ? true : alltrue([
      can(regex("^[1-9][0-9]*$", var.github_repository_ids.owner_id)),
      can(regex("^[1-9][0-9]*$", var.github_repository_ids.repository_id)),
    ])
    error_message = "github_repository_ids must contain positive numeric owner_id and repository_id values."
  }
}

variable "github_branch" {
  description = "GitHub branch allowed to assume the deployment role."
  type        = string

  validation {
    condition     = length(trimspace(var.github_branch)) > 0
    error_message = "github_branch must not be empty."
  }
}

variable "aws_region" {
  description = "AWS region in which the GitHub deployment role may modify EC2 resources."
  type        = string
}

variable "state_bucket_arn" {
  description = "ARN of the S3 bucket containing the application Terraform state."
  type        = string

  validation {
    condition     = length(trimspace(var.state_bucket_arn)) > 0
    error_message = "state_bucket_arn must not be empty."
  }
}

variable "application_state_key" {
  description = "S3 object key used for the application Terraform state."
  type        = string

  validation {
    condition     = length(trimspace(var.application_state_key)) > 0
    error_message = "application_state_key must not be empty."
  }
}
