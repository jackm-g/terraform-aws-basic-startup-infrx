output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnets
}

output "database_subnet_ids" {
  description = "IDs of the database subnets"
  value       = module.vpc.database_subnets
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.app.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.app.zone_id
}

output "ec2_instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.app.id
}

output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.app.public_ip
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.app.repository_url
}

output "application_url" {
  description = "URL to access the application"
  value       = "http://${aws_lb.app.dns_name}"
}

output "django_env_secret_arn" {
  description = "ARN of the Django environment secrets in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.django_env.arn
  sensitive   = true
}

output "django_env_secret_name" {
  description = "Name of the Django environment secrets in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.django_env.name
}

# Frontend outputs
output "s3_bucket_name" {
  description = "Name of the S3 bucket hosting the frontend"
  value       = aws_s3_bucket.frontend.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket hosting the frontend"
  value       = aws_s3_bucket.frontend.arn
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.frontend.id
}

output "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution"
  value       = aws_cloudfront_distribution.frontend.arn
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "frontend_url" {
  description = "URL to access the frontend application"
  value       = var.frontend_domain_name != null ? "https://${var.frontend_domain_name}" : "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "backend_api_url" {
  description = "Backend API URL for frontend configuration"
  value       = var.acm_certificate_arn != null ? "https://${aws_lb.app.dns_name}" : "http://${aws_lb.app.dns_name}"
}

# Database Outputs
output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "rds_port" {
  description = "RDS PostgreSQL port"
  value       = aws_db_instance.main.port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.main.db_name
}

output "rds_username" {
  description = "RDS master username"
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "database_url" {
  description = "Complete database URL for Django"
  value       = "postgresql://${aws_db_instance.main.username}:${random_password.db_password.result}@${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
  sensitive   = true
}

# Redis Outputs
output "redis_endpoint" {
  description = "Redis cluster endpoint"
  value       = aws_elasticache_replication_group.main.configuration_endpoint_address != "" ? aws_elasticache_replication_group.main.configuration_endpoint_address : aws_elasticache_replication_group.main.primary_endpoint_address
}

output "redis_port" {
  description = "Redis port"
  value       = aws_elasticache_replication_group.main.port
}

output "redis_url" {
  description = "Complete Redis URL"
  value       = var.redis_auth_token_enabled ? "redis://:${random_password.redis_auth_token[0].result}@${coalesce(aws_elasticache_replication_group.main.configuration_endpoint_address, aws_elasticache_replication_group.main.primary_endpoint_address)}:${aws_elasticache_replication_group.main.port}" : "redis://${coalesce(aws_elasticache_replication_group.main.configuration_endpoint_address, aws_elasticache_replication_group.main.primary_endpoint_address)}:${aws_elasticache_replication_group.main.port}"
  sensitive   = true
}