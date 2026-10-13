variable "hosted_zone_id" {
  description = "ID of the externally managed public Route 53 hosted zone; keep both roots aligned."
  type        = string
  default     = "Z09698437FJB59WM71X"

  validation {
    condition     = can(regex("^Z[A-Z0-9]+$", var.hosted_zone_id))
    error_message = "hosted_zone_id must be a Route 53 zone ID without the /hostedzone/ prefix."
  }
}

variable "domain_name" {
  description = "Apex domain for the application and certificate; keep both roots aligned."
  type        = string
  default     = "panroman.pl"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$", var.domain_name))
    error_message = "domain_name must be a lowercase DNS name without a wildcard or trailing dot."
  }
}

variable "aws_account_id" {
  description = "The 12-digit AWS account ID in which resources may be created."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must contain exactly 12 digits."
  }
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
  default     = "main"

  validation {
    condition     = length(trimspace(var.github_branch)) > 0
    error_message = "github_branch must not be empty."
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
  description = "Short lowercase project name used for resource names and tags."
  type        = string
  default     = "simpleproj1"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,23}[a-z0-9]$", var.project_name))
    error_message = "project_name must be 3-25 lowercase letters, numbers, or hyphens and start/end with a letter or number."
  }
}
