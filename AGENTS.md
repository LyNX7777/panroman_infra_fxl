### Create Terraform Project which enables following Infrastructure requirements for web application hosting

## Requirements
# AWS Accounts
    There will be 1 AWS accounts used for this project.
    Given account is created and will be linked as profile (account id will be provided as variable).
    
# Terraform code and state
    Terraform code is stored on github repo.
    Use AWS S3 for remote state with native locking.
# OIDC
    Enable OIDC and CI/CD for Terraform code on github with github actions.
# Web App Hosting Environments
    Application will be hosted simple single EC2 instance with docker (nginx + static html).
    Don't enable any other unnecessary AWS resources. This is only for Demo.