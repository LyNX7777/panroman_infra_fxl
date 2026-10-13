# SimpleProj: Terraform AWS demo web hosting

This repository provisions a deliberately small public web application on AWS:

- one dedicated VPC and two public subnets in different Availability Zones;
- one EC2 instance running Docker;
- one internet-facing Application Load Balancer (ALB);
- one Nginx container serving app/index.html;
- one apex A alias to the ALB in the existing public panroman.pl hosted zone;
- one DNS-validated, non-exportable ACM certificate terminating HTTPS at the ALB;
- one S3 bucket for application remote state and native S3 lockfiles;
- one GitHub Actions role authenticated through GitHub OIDC.

Traffic follows `Browser -> HTTPS -> ALB + ACM -> HTTP:80 -> Nginx`.
The ALB redirects public HTTP to HTTPS. EC2 accepts HTTP only from the ALB's
security group and retains an automatically assigned public IPv4 address for
package and container downloads. There is no Elastic IP, NAT gateway, database,
new DNS zone, SSH access, SSM access, or long-lived GitHub AWS credential.

## Module layout

The bootstrap and infrastructure directories are composition roots. Provider,
backend, account, and regional configuration remain in those roots. Reusable
AWS resources are grouped into six local modules:

- modules/terraform-state manages the protected S3 state bucket;
- modules/github-oidc manages GitHub federation and deployment permissions;
- modules/network manages the two-AZ public network;
- modules/web-server manages the EC2 instance, security group, and Docker bootstrap;
- modules/load-balancer manages the ALB, listeners, HTTP target group and registration;
- modules/dns-certificate manages the application A record and ACM certificate,
  and reads the externally managed zone and existing validation records.

The infrastructure root reads app/index.html and passes its content into the
web-server module. This keeps application content in the repository while the
module owns the EC2 user-data rendering.

## Prerequisites

- An existing AWS account.
- A local AWS profile with permission to manage S3, IAM, EC2, VPC, Route 53
  records, ACM certificates, and Elastic Load Balancing resources.
- The existing public panroman.pl zone, delegated to its Route 53 name servers,
  with the existing ACM DNS validation CNAME intact.
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
- hosted_zone_id and domain_name default to Z09698437FJB59WM71X and panroman.pl.
  Keep these values identical in bootstrap and infrastructure if overriding them.

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
| HOSTED_ZONE_ID | Optional; defaults to Z09698437FJB59WM71X |
| DOMAIN_NAME | Optional; defaults to panroman.pl |

These values are identifiers rather than credentials. Do not create or store
AWS access keys in GitHub.
If overriding the optional DNS variables, use the same values in bootstrap.

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

For an existing deployment, apply the updated bootstrap permissions locally
before merging this feature to main. With the authoritative bootstrap state
present, run:

~~~powershell
terraform -chdir=bootstrap plan -out=bootstrap.tfplan
terraform -chdir=bootstrap apply bootstrap.tfplan
~~~

The policy update adds regional ELB lifecycle permissions and permission to create
only the ELB service-linked role. EIP disassociation/release permissions remain
for migration; allocation/association permissions are removed. Route 53 changes
remain limited to the selected zone's apex A record, and certificate requests
remain limited to the selected domain and DNS validation. GitHub Actions does
not apply bootstrap changes.

For the migration from direct HTTP, review a fresh infrastructure plan before
pushing. It should add the second subnet and ALB, update the apex A record to an
alias, restrict EC2 ingress, and remove the EIP and association. The VPC, original
subnet, EC2 instance, and ACM certificate retain their Terraform addresses.
There is no staged cutover: downtime is accepted during provisioning and expiry
of the old 300-second DNS cache. Do not apply previously saved EIP-era plans.

Initialize this directory as a repository if needed, add the GitHub remote, and
push the code to main. Pull requests run formatting and validation. A push to
main, including a merged pull request, performs these serialized steps:

1. Validate both Terraform configurations and run offline Terraform tests.
2. Exchange the GitHub OIDC token for short-lived AWS credentials.
3. Initialize the application S3 backend.
4. Save a Terraform plan.
5. Apply that exact saved plan automatically.
6. Publish the Terraform outputs in the workflow summary.
7. Wait for a healthy target, verify HTTPS content and the HTTP redirect, and
   require a fresh Terraform plan to report no changes.

The workflow can also be started manually with workflow_dispatch. It never
applies code from a pull request.

## DNS and certificate ownership

The hosted zone is read by ID and is never imported, created, or destroyed by
this project. Its apex must match domain_name and it must be public. Terraform
manages panroman.pl's A alias pointing to the ALB with target health evaluation.
Alias TTL is controlled by AWS, so no explicit TTL or address list is configured.
Overwrite is disabled: if an A record already exists before the first apply,
review its ownership and deliberately import/reconcile it before retrying.
No www, wildcard, AAAA, or additional zone is created. The existing managed A
record is updated in place during migration.

The existing validation CNAME
`_57afa9f5023454ac2dc5debb27ec40b2.panroman.pl.` points to
`_580ce981157f9b199a42dd8c8dd8d6de.jkddzztszm.acm-validations.aws.`.
The module reads existing records and compares the name, type, and sole value
with the new certificate's ACM validation requirements, allowing DNS case and
trailing-dot differences. A missing or conflicting record stops validation
with an explicit error. Reconcile that record through its existing management
process; this project neither overwrites nor takes ownership of it.

ACM requests an RSA-2048, DNS-validated, non-exportable certificate in the
application region (eu-central-1 by default). Apply waits for issuance. The
certificate_arn output refers to the validated certificate. The ALB HTTPS
listener waits for validation and uses `ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09`
(TLS 1.2/1.3). No private keys are exported. Public port 80 returns a 301 redirect
to HTTPS, preserving the host, path, and query. DNS publication waits for the
listeners and target registration; target health can take longer to become ready.

Keep the externally managed validation CNAME intact for ACM renewal. See
[ACM renewal eligibility](https://docs.aws.amazon.com/acm/latest/userguide/managed-renewal.html)
and [DNS validation reuse](https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html).

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
so the ALB target can take several minutes to become healthy. Ports 80 and 443
are public only on the ALB; the EC2 security group permits HTTP only from the ALB.
Port 22 is not opened and no EC2 key pair or instance role is created.

Changing app/index.html replaces the disposable instance and updates the target
registration, while the ALB, DNS alias, and certificate remain stable. The single
instance still has downtime during replacement. Package installation and image
downloads each retry up to 10 times, with 15 seconds between attempts. The legacy
EIP comment in the bootstrap script is retained to avoid replacing the instance
solely for a comment change during this migration.

The application_url output is https://panroman.pl. The old public_ip and
direct_application_url outputs have been removed. Verify DNS, certificate, and
target health:

~~~powershell
Resolve-DnsName panroman.pl -Type NS
Resolve-DnsName panroman.pl -Type A
$albDnsName = terraform -chdir=infrastructure output -raw alb_dns_name
$targetGroupArn = terraform -chdir=infrastructure output -raw target_group_arn
$certificateArn = terraform -chdir=infrastructure output -raw certificate_arn
aws acm describe-certificate --certificate-arn $certificateArn --region eu-central-1 --profile my-aws-profile --query Certificate.Status
aws elbv2 describe-target-health --target-group-arn $targetGroupArn --region eu-central-1 --profile my-aws-profile
curl.exe -I "http://panroman.pl/example?check=1"
curl.exe --fail https://panroman.pl/
~~~

ACM must report ISSUED, the target must report healthy, and HTTP must redirect
to https://panroman.pl:443/example?check=1 (an omitted default port is equivalent).
HTTPS must serve app/index.html with a valid certificate. Check the Route 53
record's AliasTarget against the ALB DNS name; individual resolved addresses can
change. Confirm the former EIP allocation is gone and that HTTP requests to the
instance's current public IP time out. Finally, a fresh Terraform plan should
report no changes. A newly published latest AMI can independently trigger
replacement and should be reviewed separately.

Offline checks used by CI:

~~~powershell
terraform fmt -check -recursive
terraform -chdir=bootstrap init -backend=false
terraform -chdir=bootstrap validate
terraform -chdir=bootstrap test
terraform -chdir=infrastructure init -backend=false
terraform -chdir=infrastructure validate
terraform -chdir=infrastructure test
~~~

Infrastructure tests use a mocked AWS provider and exercise certificate validation,
DNS aliases, the complete dependency graph, two Availability Zones, listeners,
target registration, and security-group restrictions. Bootstrap tests compute IAM
policy documents locally using fake credentials with AWS lookups disabled. They
run plans only and verify regional ELB permissions and EIP cleanup permissions.
The tests create no AWS resources.

## Design and security notes

- The latest available AWS-owned Amazon Linux 2023 x86-64 AMI is selected at
  plan time.
- IMDSv2 is required and the root EBS volume is encrypted.
- The GitHub role can access only the application state object and lockfile.
- EC2 and ELB write permissions are limited to the operations required by this stack
  and to eu-central-1. Read-only EC2 Describe operations are needed by the AWS
  provider.
- No shell access is configured. Replace the instance through Terraform instead
  of modifying it manually.
- The site uses HTTPS and is single-instance. It is not a production
  high-availability design.

## Cost and teardown

The EC2 instance, EBS volume, ALB hours and capacity units, public IPv4 addresses
on the ALB and instance, S3 storage, and network data transfer can incur AWS
charges. Removing the Elastic IP does not remove public IPv4 charges. An internet
gateway has no hourly charge, but traffic charges can still apply. There is no
automatic destroy workflow.

Destroy resources in this order:

1. Destroy the application while its S3 backend is available:

~~~powershell
terraform -chdir=infrastructure destroy
~~~

This deletes the ALB, listeners, target group, instance, network, application A
alias, and ACM certificate. The hosted zone, NS/SOA records, and pre-existing ACM
validation CNAME remain externally managed and are retained. The shared AWS ELB
service-linked role is not managed or deleted by this project.

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
