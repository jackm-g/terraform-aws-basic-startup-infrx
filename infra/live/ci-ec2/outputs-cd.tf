# CD Pipeline Outputs
# These outputs provide the necessary information for setting up the GitHub Actions CD pipeline

# GitHub OIDC Provider ARN
output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

# GitHub CD Role ARN
output "github_cd_role_arn" {
  description = "ARN of the GitHub CD role for assuming in workflows"
  value       = aws_iam_role.github_cd_role.arn
}

# ECR Repository URL
output "ecr_repository_url" {
  description = "URL of the ECR repository in this account"
  value       = data.aws_ecr_repository.app.repository_url
}

# ECR Repository Name (for GitHub Actions variables)
output "ecr_repository_name" {
  description = "Name of the ECR repository in this account"
  value       = data.aws_ecr_repository.app.name
}

# AWS Account ID (useful for CD pipeline setup)
output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

# AWS Region
output "aws_region" {
  description = "AWS Region"
  value       = data.aws_region.current.name
}

# Summary output for GitHub Actions setup
output "github_actions_setup_summary" {
  description = "Summary of values needed for GitHub Actions CD setup"
  value = {
    aws_region                    = data.aws_region.current.name
    aws_account_id               = data.aws_caller_identity.current.account_id
    aws_role_to_assume           = aws_iam_role.github_cd_role.arn
    ecr_repository_name          = data.aws_ecr_repository.app.name
    ecr_repository_url           = data.aws_ecr_repository.app.repository_url
    github_repo                  = var.github_repo
    account_type                 = "Deploy this in both dev/staging and prod AWS accounts"
  }
}
