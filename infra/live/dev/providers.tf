terraform {
  required_version = ">= 1.12.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.8.0" }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile # e.g., your SSO profile name
}

