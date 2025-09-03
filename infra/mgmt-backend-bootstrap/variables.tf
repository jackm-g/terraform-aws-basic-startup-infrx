variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "profile" {
  description = "AWS profile for management account"
  type        = string
}

variable "bucket_name" {
  description = "S3 bucket name for management account Terraform state"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name for management account state locking"
  type        = string
  default     = "mgmt-terraform-locks"
}
