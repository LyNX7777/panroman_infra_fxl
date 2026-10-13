output "state_bucket_name" {
  description = "S3 bucket used by the bootstrap and application Terraform states."
  value       = module.terraform_state.bucket_name
}

output "github_actions_role_arn" {
  description = "IAM role ARN to store as the GitHub AWS_ROLE_ARN repository variable."
  value       = module.github_oidc.role_arn
}

output "aws_region" {
  description = "AWS region to store as the GitHub AWS_REGION repository variable."
  value       = var.aws_region
}

output "github_oidc_subject" {
  description = "Exact GitHub OIDC subject accepted by the deployment role."
  value       = module.github_oidc.subject
}
