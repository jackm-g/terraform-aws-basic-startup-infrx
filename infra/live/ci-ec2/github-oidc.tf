# GitHub OIDC Provider and CD Role Configuration
# This configures AWS for GitHub Actions OIDC authentication and ECR access

# GitHub OIDC Provider (one per AWS account)
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"] # GitHub's OIDC thumbprint

  tags = merge(var.tags, {
    Name = "GitHub-OIDC-Provider"
  })
}

# GitHubCDRole - for CD pipeline ECR access
resource "aws_iam_role" "github_cd_role" {
  name = "GitHubCDRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        },
        StringLike = {
          # Limit to the specific repo and allow main/staging branches
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:ref:refs/heads/*"
        }
      }
    }]
  })

  tags = merge(var.tags, {
    Name = "GitHubCDRole"
    Purpose = "CD-Pipeline-ECR-Access"
  })
}

# ECR-only least privilege policy for CD pipeline
resource "aws_iam_policy" "ecr_push_policy" {
  name        = "EcrPushPolicy"
  description = "Allows ECR push operations for GitHub Actions CD pipeline"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:BatchDeleteImage"
        ],
        Resource = [
          data.aws_ecr_repository.app.arn
        ]
      }
    ]
  })

  tags = var.tags
}

# Attach ECR policy to CD role
resource "aws_iam_role_policy_attachment" "github_cd_ecr_attach" {
  role       = aws_iam_role.github_cd_role.name
  policy_arn = aws_iam_policy.ecr_push_policy.arn
}
