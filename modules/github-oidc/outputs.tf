output "role_arn" {
  description = "ARN of the IAM role assumed by GitHub Actions."
  value       = aws_iam_role.github_actions.arn
}

output "subject" {
  description = "Exact GitHub OIDC subject accepted by the deployment role."
  value       = local.github_oidc_subject
}
