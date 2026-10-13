locals {
  github_repository_parts = split("/", var.github_repository)
  github_oidc_repository = var.github_repository_ids == null ? var.github_repository : format(
    "%s@%s/%s@%s",
    local.github_repository_parts[0],
    var.github_repository_ids.owner_id,
    local.github_repository_parts[1],
    var.github_repository_ids.repository_id,
  )
  github_oidc_subject = "repo:${local.github_oidc_repository}:ref:refs/heads/${var.github_branch}"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]
}

data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    sid     = "GitHubActionsMainBranch"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [local.github_oidc_subject]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name                 = "${var.project_name}-github-actions"
  description          = "Deploy ${var.project_name} from the trusted GitHub main branch"
  assume_role_policy   = data.aws_iam_policy_document.github_actions_trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "github_actions_permissions" {
  statement {
    sid       = "ListTerraformState"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [var.state_bucket_arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values = [
        var.application_state_key,
        "${var.application_state_key}.tflock",
      ]
    }
  }

  statement {
    sid    = "ReadWriteTerraformState"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = [
      "${var.state_bucket_arn}/${var.application_state_key}",
    ]
  }

  statement {
    sid    = "ManageTerraformStateLock"
    effect = "Allow"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = [
      "${var.state_bucket_arn}/${var.application_state_key}.tflock",
    ]
  }

  statement {
    sid       = "ReadEC2Configuration"
    effect    = "Allow"
    actions   = ["ec2:Describe*"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }

  statement {
    sid    = "ManageDemoEC2AndNetwork"
    effect = "Allow"
    actions = [
      "ec2:AllocateAddress",
      "ec2:AssociateAddress",
      "ec2:AssociateRouteTable",
      "ec2:AttachInternetGateway",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateInternetGateway",
      "ec2:CreateRoute",
      "ec2:CreateRouteTable",
      "ec2:CreateSecurityGroup",
      "ec2:CreateSubnet",
      "ec2:CreateTags",
      "ec2:CreateVpc",
      "ec2:DeleteInternetGateway",
      "ec2:DeleteRoute",
      "ec2:DeleteRouteTable",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteSubnet",
      "ec2:DeleteTags",
      "ec2:DeleteVpc",
      "ec2:DetachInternetGateway",
      "ec2:DisassociateAddress",
      "ec2:DisassociateRouteTable",
      "ec2:ModifyInstanceAttribute",
      "ec2:ModifySecurityGroupRules",
      "ec2:ModifySubnetAttribute",
      "ec2:ModifyVpcAttribute",
      "ec2:RebootInstances",
      "ec2:ReleaseAddress",
      "ec2:ReplaceRouteTableAssociation",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RunInstances",
      "ec2:StartInstances",
      "ec2:StopInstances",
      "ec2:TerminateInstances",
      "ec2:UpdateSecurityGroupRuleDescriptionsEgress",
      "ec2:UpdateSecurityGroupRuleDescriptionsIngress",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }
}

# Route 53 is global; do not apply the EC2 RequestedRegion condition here.
data "aws_iam_policy_document" "dns_certificate_permissions" {
  statement {
    sid    = "ReadExistingHostedZone"
    effect = "Allow"
    actions = [
      "route53:GetHostedZone",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResource",
    ]
    resources = ["arn:aws:route53:::hostedzone/${var.hosted_zone_id}"]
  }

  statement {
    sid       = "ManageApplicationARecord"
    effect    = "Allow"
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = ["arn:aws:route53:::hostedzone/${var.hosted_zone_id}"]

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "route53:ChangeResourceRecordSetsNormalizedRecordNames"
      values   = [trimsuffix(lower(var.domain_name), ".")]
    }

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "route53:ChangeResourceRecordSetsRecordTypes"
      values   = ["A"]
    }
  }

  statement {
    sid       = "WaitForDNSChanges"
    effect    = "Allow"
    actions   = ["route53:GetChange"]
    resources = ["arn:aws:route53:::change/*"]
  }

  statement {
    sid       = "RequestApplicationCertificate"
    effect    = "Allow"
    actions   = ["acm:RequestCertificate"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "acm:DomainNames"
      values   = [trimsuffix(lower(var.domain_name), ".")]
    }

    condition {
      test     = "StringEquals"
      variable = "acm:ValidationMethod"
      values   = ["DNS"]
    }
  }

  statement {
    sid    = "ManageApplicationRegionCertificates"
    effect = "Allow"
    actions = [
      "acm:AddTagsToCertificate",
      "acm:DeleteCertificate",
      "acm:DescribeCertificate",
      "acm:ListTagsForCertificate",
      "acm:RemoveTagsFromCertificate",
    ]
    resources = ["arn:aws:acm:${var.aws_region}:${var.aws_account_id}:certificate/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }
}

data "aws_iam_policy_document" "deployment_permissions" {
  source_policy_documents = [
    data.aws_iam_policy_document.github_actions_permissions.json,
    data.aws_iam_policy_document.dns_certificate_permissions.json,
  ]
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "${var.project_name}-terraform-deployment"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.deployment_permissions.json
}
