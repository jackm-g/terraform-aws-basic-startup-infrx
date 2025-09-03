output "s3_bucket_name" {
  description = "Name of the S3 bucket for dev account Terraform state"
  value       = aws_s3_bucket.dev_terraform_state.id
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for dev account state locking"
  value       = aws_dynamodb_table.dev_terraform_locks.name
}

output "dev_backend_config" {
  description = "Backend configuration for dev account projects"
  value = {
    bucket         = aws_s3_bucket.dev_terraform_state.id
    region         = var.region
    lock_file = aws_dynamodb_table.dev_terraform_locks.name
    encrypt        = true
  }
}
