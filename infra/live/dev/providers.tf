terraform {
  required_version = ">= 1.12.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.8.0" }
  }
}

# Get the deployment role ARN from org-roles state in management account
# Only needed when using cross-account role assumption
data "terraform_remote_state" "org_roles" {
  count = var.use_cross_account_role ? 1 : 0
  backend = "s3"
  config = {
    bucket = "cgm-mgmt-terraform-state"  # Management account backend
    key    = "org-roles/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
  
  # Assume the TerraformDeployRole in the dev account
  # This allows management account users to deploy to dev account
  # And allows direct dev account users to work without role assumption
  dynamic "assume_role" {
    for_each = var.use_cross_account_role ? [1] : []
    content {
      role_arn     = data.terraform_remote_state.org_roles[0].outputs.deploy_role_arns.dev
      session_name = "terraform-dev-deployment"
    }
  }
}