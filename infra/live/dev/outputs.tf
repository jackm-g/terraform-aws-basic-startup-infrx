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