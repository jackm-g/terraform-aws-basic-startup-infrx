output "s3_bucket_name" {
  description = "Name of the S3 bucket for management account Terraform state"
  value       = aws_s3_bucket.mgmt_terraform_state.id
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for management account state locking"
  value       = aws_dynamodb_table.mgmt_terraform_locks.name
}

output "mgmt_backend_config" {
  description = "Backend configuration for management account projects"
  value = {
    bucket         = aws_s3_bucket.mgmt_terraform_state.id
    region         = var.region
    dynamodb_table = aws_dynamodb_table.mgmt_terraform_locks.name
    encrypt        = true
  }
}
