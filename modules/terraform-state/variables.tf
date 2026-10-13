variable "bucket_name" {
  description = "Globally unique name of the S3 bucket that stores Terraform state."
  type        = string

  validation {
    condition     = length(var.bucket_name) >= 3 && length(var.bucket_name) <= 63
    error_message = "bucket_name must contain between 3 and 63 characters."
  }
}

variable "application_state_key" {
  description = "S3 object key reserved for the application Terraform state."
  type        = string

  validation {
    condition     = length(trimspace(var.application_state_key)) > 0
    error_message = "application_state_key must not be empty."
  }
}

