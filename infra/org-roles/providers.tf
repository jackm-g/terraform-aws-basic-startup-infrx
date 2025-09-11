terraform {
  required_version = ">= 1.12.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.8.0"
    }
  }
}

# Get account IDs from Stage 1 (org-bootstrap) - from management account backend
data "terraform_remote_state" "bootstrap" {
  backend = "s3"
  config = {
    bucket = var.tfstate_bucket
    key    = "org-bootstrap/terraform.tfstate"
    region = "us-east-1"
  }
}

# Management account provider (for trust policy)
provider "aws" {
  region  = var.region
  profile = var.profile
}

# Member account providers that assume into the created accounts
provider "aws" {
  alias   = "member_dev"
  region  = var.region
  profile = var.profile
  assume_role {
    role_arn     = "arn:aws:iam::${data.terraform_remote_state.bootstrap.outputs.account_ids.dev}:role/OrganizationAccountAccessRole"
    session_name = "org-bootstrap"
  }
}

provider "aws" {
  alias   = "member_prod"
  region  = var.region
  profile = var.profile
  assume_role {
    role_arn     = "arn:aws:iam::${data.terraform_remote_state.bootstrap.outputs.account_ids.prod}:role/OrganizationAccountAccessRole"
    session_name = "org-bootstrap"
  }
}
