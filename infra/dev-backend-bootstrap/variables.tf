variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "profile" {
  description = "AWS profile for dev account"
  type        = string
}

variable "bucket_name" {
  description = "S3 bucket name for dev account Terraform state"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name for dev account state locking"
  type        = string
  default     = "dev-terraform-locks"
}
