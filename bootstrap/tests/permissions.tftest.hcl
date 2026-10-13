# Policy documents are computed locally by the real provider. Plan only, with
# fake credentials and all account/metadata lookups disabled: no AWS access.
provider "aws" {
  region                      = "eu-central-1"
  access_key                  = "offline-test"
  secret_key                  = "offline-test"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

run "deployment_permissions" {
  command = plan

  module { source = "../modules/github-oidc" }

  variables {
    aws_account_id        = "123456789012"
    aws_region            = "eu-central-1"
    hosted_zone_id        = "Z09698437FJB59WM71X"
    domain_name           = "panroman.pl"
    project_name          = "demo"
    github_repository     = "example/demo"
    github_repository_ids = null
    github_branch         = "main"
    state_bucket_arn      = "arn:aws:s3:::demo-state"
    application_state_key = "application/terraform.tfstate"
  }

  assert {
    condition = alltrue([
      for action in ["elasticloadbalancing:CreateLoadBalancer", "elasticloadbalancing:CreateListener", "elasticloadbalancing:RegisterTargets", "elasticloadbalancing:DeleteLoadBalancer", "elasticloadbalancing:ModifyListenerAttributes"] :
      contains(one([for s in jsondecode(data.aws_iam_policy_document.deployment_permissions.json).Statement : s if s.Sid == "ManageApplicationLoadBalancer"]).Action, action)
    ])
    error_message = "The deployment role must manage the ALB lifecycle and instance registration."
  }

  assert {
    condition = (
      one([for s in jsondecode(data.aws_iam_policy_document.deployment_permissions.json).Statement : s if s.Sid == "ManageApplicationLoadBalancer"]).Condition.StringEquals["aws:RequestedRegion"] == "eu-central-1" &&
      one([for s in jsondecode(data.aws_iam_policy_document.deployment_permissions.json).Statement : s if s.Sid == "CreateELBServiceLinkedRole"]).Condition.StringEquals["iam:AWSServiceName"] == "elasticloadbalancing.amazonaws.com" &&
      one([for s in jsondecode(data.aws_iam_policy_document.deployment_permissions.json).Statement : s if s.Sid == "CreateELBServiceLinkedRole"]).Resource == "arn:aws:iam::123456789012:role/aws-service-role/elasticloadbalancing.amazonaws.com/AWSServiceRoleForElasticLoadBalancing"
    )
    error_message = "ELB writes must remain regional and service-linked role creation must be restricted to ELB."
  }

  assert {
    condition = (
      !strcontains(data.aws_iam_policy_document.deployment_permissions.json, "ec2:AllocateAddress") &&
      !strcontains(data.aws_iam_policy_document.deployment_permissions.json, "ec2:AssociateAddress") &&
      strcontains(data.aws_iam_policy_document.deployment_permissions.json, "ec2:DisassociateAddress") &&
      strcontains(data.aws_iam_policy_document.deployment_permissions.json, "ec2:ReleaseAddress")
    )
    error_message = "Retain EIP cleanup permissions without permitting allocation or association."
  }
}
