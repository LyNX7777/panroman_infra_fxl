locals {
  application_state_key = "application/terraform.tfstate"
  state_bucket_name     = "${var.project_name}-tfstate-${var.aws_account_id}-${var.aws_region}"
}

module "terraform_state" {
  source = "../modules/terraform-state"

  bucket_name           = local.state_bucket_name
  application_state_key = local.application_state_key
}

module "github_oidc" {
  source = "../modules/github-oidc"

  project_name          = var.project_name
  github_repository     = var.github_repository
  github_repository_ids = var.github_repository_ids
  github_branch         = var.github_branch
  aws_region            = var.aws_region
  state_bucket_arn      = module.terraform_state.bucket_arn
  application_state_key = local.application_state_key
}
