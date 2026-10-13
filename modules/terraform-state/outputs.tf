output "bucket_name" {
  description = "Name of the S3 bucket that stores Terraform state."
  value       = aws_s3_bucket.terraform_state.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket that stores Terraform state."
  value       = aws_s3_bucket.terraform_state.arn
}

