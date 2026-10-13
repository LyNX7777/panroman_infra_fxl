# SimpleProj1: Terraform AWS demo web hosting

This repository provisions a deliberately small public web application on AWS:

- one dedicated VPC and one public subnet in one Availability Zone;
- one EC2 instance running Docker;
- one Nginx container serving app/index.html;
- one S3 bucket for application remote state and native S3 lockfiles;
- one GitHub Actions role authenticated through GitHub OIDC.

It does not create a NAT gateway, load balancer, database, DNS zone, TLS
certificate, SSH access, SSM access, or long-lived GitHub AWS credentials.

## Module layout

The bootstrap and infrastructure directories are composition roots. Provider,
backend, account, and regional configuration remain in those roots. Reusable
AWS resources are grouped into four local modules:

- modules/terraform-state manages the protected S3 state bucket;
- modules/github-oidc manages GitHub federation and deployment permissions;
- modules/network manages the single-AZ public network;
- modules/web-server manages the EC2 instance, security group, and Docker
  bootstrap template.

The infrastructure root reads app/index.html and passes its content into the
web-server module. This keeps application content in the repository while the
module owns the EC2 user-data rendering.

## Prerequisites

- An existing AWS account.
- A local AWS profile with permission to manage S3, IAM, EC2, and VPC resources.
- Terraform 1.10 or newer. The workflow currently uses Terraform 1.16.2.
- AWS CLI v2 for identity checks.
- A GitHub repository whose default deployment branch is main.

All commands below are PowerShell commands run from the repository root.

## 1. Check the target AWS account

Never bootstrap until this command returns the account you intend to use:

~~~powershell
aws sts get-caller-identity --profile my-aws-profile
~~~

The Terraform provider also uses allowed_account_ids as a second guard against
deploying into the wrong account.

## 2. Bootstrap state and GitHub OIDC

Create a local variables file:

~~~powershell
Copy-Item bootstrap/terraform.tfvars.example bootstrap/terraform.tfvars
~~~

Edit bootstrap/terraform.tfvars and set:

- aws_account_id to the 12-digit AWS account ID;
- aws_profile to the local profile name;
- github_repository to the exact owner/repository value;
- github_repository_ids to the numeric owner.id and id returned by
  https://api.github.com/repos/OWNER/REPOSITORY when using immutable OIDC subjects.
  Omit this object only for repositories still using legacy name-only subjects.

GitHub repositories created after July 15, 2026 use immutable OIDC subjects,
which include both names and numeric IDs. Renamed/transferred repositories and
repositories that opt in also use this format. See
[GitHub's OIDC documentation](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws).

The bootstrap root has an explicit local backend at
bootstrap/terraform.tfstate. Initialize and apply it once from the machine that
will retain this state:

~~~powershell
terraform -chdir=bootstrap init
terraform -chdir=bootstrap fmt -check
terraform -chdir=bootstrap validate
terraform -chdir=bootstrap plan -out=bootstrap.tfplan
terraform -chdir=bootstrap apply bootstrap.tfplan
~~~

Capture the outputs after the apply:

~~~powershell
$stateBucket = terraform -chdir=bootstrap output -raw state_bucket_name
$actionsRole = terraform -chdir=bootstrap output -raw github_actions_role_arn
~~~

The bucket has public access blocked, AES-256 server-side encryption,
versioning, and lifecycle protection. GitHub's OIDC provider is created without
a manually maintained certificate thumbprint because AWS validates GitHub
against its trusted root CA library.

The local bootstrap state is authoritative for the state bucket and GitHub OIDC
resources. Never migrate it to S3, upload it, or commit it. Keep
bootstrap/terraform.tfstate and any terraform.tfstate.backup file securely
stored on this machine, with a separate secure local or offline backup. Losing
this state requires importing the bootstrap resources or cleaning them up
manually.

Only the application infrastructure uses remote state. Its state is stored at
application/terraform.tfstate in the S3 bucket and uses native S3 locking through
use_lockfile = true; no DynamoDB table is required.

Do not commit terraform.tfvars, saved plans, local state, state backups, or the
.terraform directories. They are ignored by .gitignore.

## 3. Configure GitHub repository variables

In GitHub, open Settings, then Secrets and variables, Actions, and Variables.
Create these repository variables:

| Variable | Value |
| --- | --- |
| AWS_ACCOUNT_ID | The same 12-digit AWS account ID |
| AWS_REGION | eu-central-1 |
| TF_STATE_BUCKET | The value of $stateBucket |
| AWS_ROLE_ARN | The value of $actionsRole |

These values are identifiers rather than credentials. Do not create or store
AWS access keys in GitHub.

The OIDC role trust policy accepts only tokens for the configured repository
and refs/heads/main. Pull request jobs receive no id-token permission and do not
access AWS.

### Troubleshooting OIDC role assumption

If GitHub reports `Not authorized to perform sts:AssumeRoleWithWebIdentity`,
check the role's **Trust relationships** in IAM. The audience must be
`sts.amazonaws.com`, and the subject must exactly match the repository's format:

- Legacy: `repo:OWNER/REPOSITORY:ref:refs/heads/main`
- Immutable: `repo:OWNER@OWNER_ID/REPOSITORY@REPOSITORY_ID:ref:refs/heads/main`

Set `github_repository_ids` for the immutable format. With the original
`bootstrap/terraform.tfstate` present, create and review a new bootstrap plan,
then apply it locally to update the role. Pushing Terraform code alone does not
update bootstrap resources; GitHub deploys only the infrastructure root. If the
bootstrap state is missing, restore its secure backup before running an apply.

Verify `AWS_ROLE_ARN` matches the bootstrap role and run the workflow from the
trusted branch. This workflow has no GitHub environment; adding one changes the
subject format and requires a corresponding trust-policy change. Keep the exact
subject restriction instead of allowing every repository or branch.

## 4. Push and deploy

Initialize this directory as a repository if needed, add the GitHub remote, and
push the code to main. Pull requests run formatting and validation. A push to
main, including a merged pull request, performs these serialized steps:

1. Validate both Terraform configurations.
2. Exchange the GitHub OIDC token for short-lived AWS credentials.
3. Initialize the application S3 backend.
4. Save a Terraform plan.
5. Apply that exact saved plan automatically.
6. Publish the Terraform outputs in the workflow summary.

The workflow can also be started manually with workflow_dispatch. It never
applies code from a pull request.

## Local application commands

GitHub Actions is the normal deployment path. For a local plan or apply, create
an ignored variables file:

~~~powershell
Copy-Item infrastructure/terraform.tfvars.example infrastructure/terraform.tfvars
~~~

Edit the account ID and profile, then initialize the remote backend:

~~~powershell
terraform -chdir=infrastructure init -backend-config="bucket=$stateBucket" -backend-config="region=eu-central-1" -backend-config="profile=my-aws-profile"
terraform -chdir=infrastructure plan
terraform -chdir=infrastructure apply
~~~

## Verify the deployment

Get the application URL:

~~~powershell
$applicationUrl = terraform -chdir=infrastructure output -raw application_url
Invoke-WebRequest $applicationUrl
~~~

Cloud-init must install Docker and download the Nginx image on the first boot,
so HTTP can take several minutes to become available. Port 80 is public. Port
22 is not opened and no EC2 key pair or instance role is created.

Changing app/index.html changes EC2 user data. Terraform then replaces the
disposable instance and the public IPv4 address may change. Running a second
plan after a completed deployment should report no changes.

## Design and security notes

- The latest available AWS-owned Amazon Linux 2023 x86-64 AMI is selected at
  plan time.
- IMDSv2 is required and the root EBS volume is encrypted.
- The GitHub role can access only the application state object and lockfile.
- EC2 write permissions are limited to the operations required by this stack
  and to eu-central-1. Read-only EC2 Describe operations are needed by the AWS
  provider.
- No shell access is configured. Replace the instance through Terraform instead
  of modifying it manually.
- The site is HTTP-only and single-instance. It is not a production
  high-availability design.

## Cost and teardown

The EC2 instance, EBS volume, public IPv4 address, S3 storage, and network data
transfer can incur AWS charges. An internet gateway has no hourly charge, but
traffic charges can still apply. There is no automatic destroy workflow.

Destroy resources in this order:

1. Destroy the application while its S3 backend is available:

~~~powershell
terraform -chdir=infrastructure destroy
~~~

2. Confirm the authoritative bootstrap state is still present. Stop if this
   returns False:

~~~powershell
Test-Path -LiteralPath bootstrap/terraform.tfstate
~~~

3. In modules/terraform-state/main.tf, deliberately remove the lifecycle block
   containing prevent_destroy = true from the state bucket.
4. Review a bootstrap destroy plan carefully, then destroy:

~~~powershell
terraform -chdir=bootstrap plan -destroy
terraform -chdir=bootstrap destroy
~~~

The bucket uses force_destroy only after lifecycle protection is deliberately
removed, allowing Terraform to delete the versioned state objects during final
demo cleanup. Never remove that protection while any application state is still
needed.
