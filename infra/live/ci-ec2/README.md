# GitHub Actions CI/CD Infrastructure

Deploys self-hosted GitHub Actions runner + OIDC authentication for secure CI/CD pipelines.

## Prerequisites

1. **GitHub PAT**: Personal Access Token with `repo` and `admin:repo_hook` permissions
2. **AWS Credentials**: Configured with appropriate permissions
3. **EC2 Key Pair**: For SSH access to runner instance
4. **ECR Repository**: Must exist before deploying CI infrastructure

## Quick Setup

```bash
# 1. Configure terraform.tfvars with your values:
# - github_repo: "owner/repo"
# - key_name: "your-ec2-key" 
# - allowed_ssh_cidrs: ["your.ip.address/32"]
# - ecr_repository_name: "your-app-name"

# 2. Set GitHub token and deploy
export TF_VAR_github_token="your_github_personal_access_token"
terraform init && terraform apply
```

## Infrastructure Created

**CI Runner**:
- EC2 t3.large instance (Ubuntu 24.04, Docker, Node.js)
- Self-hosted GitHub Actions runner
- Elastic IP + Security Groups
- 50GB encrypted storage

**CD Authentication**:
- GitHub OIDC Provider
- GitHubCDRole with ECR-only permissions
- Scoped to your repository branches

## 🔧 GitHub Repository Setup

**CRITICAL**: Configure these in your GitHub repository after deployment:

### Repository Variables
`Settings > Secrets and variables > Actions > Repository variables`:
```
AWS_ACCOUNT_ID_PROD: [Production AWS Account ID]
AWS_ACCOUNT_ID_STAGING: [Staging AWS Account ID]
AWS_REGION: [Your AWS region, e.g., us-east-1]
AWS_ROLE_TO_ASSUME_PROD: [Production GitHub CD Role ARN]
AWS_ROLE_TO_ASSUME_STAGING: [Staging GitHub CD Role ARN]
ECR_REPO_PROD: [Production ECR Repository Name]
ECR_REPO_STAGING: [Staging ECR Repository Name]
```

### Github Workflow
Create a `.github/workflows/<FILE>.yml` that causes pushes to your desired branches to trigger CI/CD actions on this private github actions runner. 

## Post-Deployment

### Get Setup Values
```bash
terraform output github_actions_setup_summary
```

### Access Runner
```bash
ssh -i /path/to/your-key.pem ubuntu@$(terraform output -raw instance_public_ip)
```

### Monitor Runner
- Service status: `systemctl status actions.runner.*`
- Logs: `/opt/actions-runner/_diag/`
- Environment file: `/opt/cgm/.env.test`

## Multi-Account Strategy

Deploy this CI infrastructure in **each AWS account** (dev, staging, prod) with separate:
- AWS profiles in `terraform.tfvars`
- ECR repositories per account
- GitHub repository secrets per environment