terraform {
  required_version = ">= 1.12.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.8.0"
    }
  }
}

# Management account (runs org resources)
provider "aws" {
  region  = var.region
  profile = var.profile
}

data "aws_caller_identity" "mgmt" {}
