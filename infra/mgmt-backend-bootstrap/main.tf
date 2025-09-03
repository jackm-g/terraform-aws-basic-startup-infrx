# Management Account Backend Bootstrap
# Creates S3 bucket and DynamoDB table for management account Terraform state

terraform {
  required_version = ">= 1.12.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.8.0"
    }
  }
  # Uses local state initially
}

provider "aws" {
  region  = var.region
  profile = var.profile
}

data "aws_caller_identity" "current" {}

# S3 bucket for management account Terraform state
resource "aws_s3_bucket" "mgmt_terraform_state" {
  bucket = var.bucket_name

  tags = {
    Name        = "Management Account Terraform State"
    Environment = "management"
    Purpose     = "terraform-backend"
    Account     = "management"
  }
}

resource "aws_s3_bucket_versioning" "mgmt_terraform_state" {
  bucket = aws_s3_bucket.mgmt_terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "mgmt_terraform_state" {
  bucket = aws_s3_bucket.mgmt_terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "mgmt_terraform_state" {
  bucket = aws_s3_bucket.mgmt_terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for management account state locking
resource "aws_dynamodb_table" "mgmt_terraform_locks" {
  name           = var.dynamodb_table_name
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Management Account Terraform Locks"
    Environment = "management"
    Purpose     = "terraform-backend"
    Account     = "management"
  }
}
