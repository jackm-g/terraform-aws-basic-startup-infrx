# AWS Infrastructure for GitHub Actions CD Pipeline

This documentation covers the AWS infrastructure components that have been implemented to support the GitHub Actions CD pipeline as outlined in `CD-plan.md`.

## 🏗️ Infrastructure Components

### 1. GitHub OIDC Provider (`github-oidc.tf`)

- **Resource**: `aws_iam_openid_connect_provider.github`
- **Purpose**: Enables GitHub Actions to authenticate with AWS using OIDC tokens (no long-lived access keys)
- **Thumbprint**: Uses GitHub's official OIDC thumbprint for secure authentication

### 2. GitHub CD Role (`github-oidc.tf`)

- **Resource**: `aws_iam_role.github_cd_role`
- **Name**: `GitHubCDRole`
- **Purpose**: Least-privilege role for CD pipeline ECR operations
- **Trust Policy**: 
  - Limited to specific GitHub repository: `CGM-Sports/ai-dashboard`
  - Allows `main` and `staging` branches via `ref:refs/heads/*`
  - Uses `sts:AssumeRoleWithWebIdentity` for OIDC authentication

### 3. ECR Repository (External - Configured via Variable)

This infrastructure references your existing ECR repository in the current AWS account rather than creating a new one. You must configure the repository name in `terraform.tfvars`:

#### Required Configuration
- **ECR Repository**: Set via `ecr_repository_name` variable
- **AWS Region**: Set via `aws_region` variable (default: us-east-1)

#### Account Separation Strategy
Deploy this infrastructure separately in each AWS account:
- **Dev/Staging Account**: Set `ecr_repository_name = "cgmdev/backend"`
- **Production Account**: Set `ecr_repository_name = "cgmprod/backend"`

#### Prerequisites
Your existing ECR repository should have:
- Scan on push enabled (recommended)
- Appropriate lifecycle policies for cost management
- Proper tagging strategy

### 4. CI Runner ECR Permissions (`ci-ec2.tf`)

- **Enhanced**: Existing CI runner role with ECR permissions
- **Purpose**: Allows the self-hosted GitHub Actions runner to push images to ECR
- **Permissions**: Full ECR operations for the configured repository in this account

## 🔧 GitHub Actions Setup Requirements

After applying this Terraform configuration, you'll need to set up the following in your GitHub repository:

### Repository Variables/Secrets

You'll need to set up variables for both accounts after deploying to each:

```bash
# AWS Configuration (from dev/staging account)
AWS_REGION=us-east-1
AWS_ACCOUNT_ID_STAGING=<dev_account_id>
AWS_ROLE_TO_ASSUME_STAGING=<dev_github_cd_role_arn>
ECR_REPO_STAGING=<dev_ecr_repository_name>

# AWS Configuration (from production account)  
AWS_ACCOUNT_ID_PROD=<prod_account_id>
AWS_ROLE_TO_ASSUME_PROD=<prod_github_cd_role_arn>
ECR_REPO_PROD=<prod_ecr_repository_name>
```

### Terraform Outputs Reference

After deployment, use these outputs for GitHub Actions setup:

```bash
terraform output github_actions_setup_summary
```

This will provide all the necessary values for configuring your CD pipeline.

## 🚀 Deployment Instructions

### Deploy to Dev/Staging Account

1. **Configure for Dev/Staging**:
   ```bash
   # Set AWS profile for dev/staging account
   export AWS_PROFILE=dev-staging
   
   # Edit terraform.tfvars
   ecr_repository_name = "cgmdev/backend"
   aws_region          = "us-east-1"
   ```

2. **Apply Terraform Configuration**:
   ```bash
   cd infra/live/ci-ec2
   terraform init
   terraform plan
   terraform apply
   ```

3. **Capture Dev/Staging Outputs**:
   ```bash
   terraform output github_actions_setup_summary
   ```

### Deploy to Production Account

1. **Configure for Production**:
   ```bash
   # Set AWS profile for production account
   export AWS_PROFILE=production
   
   # Edit terraform.tfvars
   ecr_repository_name = "cgmprod/backend"
   aws_region          = "us-east-1"
   ```

2. **Apply Terraform Configuration**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. **Capture Production Outputs**:
   ```bash
   terraform output github_actions_setup_summary
   ```

4. **Configure GitHub Repository**:
   - Set the repository variables/secrets using outputs from both accounts
   - Implement the CD workflow as described in `CD-plan.md`

## 🔒 Security Features

- **OIDC Authentication**: No long-lived AWS access keys in GitHub
- **Least Privilege**: Roles have minimal permissions (ECR operations only)
- **Repository Scoping**: Trust policies limit access to specific repository
- **Branch Filtering**: Can be further restricted to specific branches
- **Encrypted Storage**: ECR repositories use AES256 encryption
- **Image Scanning**: Automatic vulnerability scanning on image push
- **Lifecycle Management**: Automatic cleanup of old images to control costs

## 📊 Cost Optimization

- **Lifecycle Policies**: Automatically remove old images to minimize storage costs
- **Efficient Tagging**: Uses semantic tagging strategy for better organization
- **Resource Tagging**: All resources tagged for cost allocation and management

## 🔍 Monitoring & Maintenance

- **ECR Scan Results**: Monitor scan results for security vulnerabilities
- **Image Lifecycle**: Review lifecycle policies periodically
- **IAM Permissions**: Regular audit of role permissions
- **GitHub OIDC**: Monitor OIDC token usage and authentication patterns

## 🛠️ Troubleshooting

### Common Issues

1. **OIDC Authentication Failures**:
   - Verify GitHub repository name matches exactly
   - Check branch name in trust policy conditions
   - Ensure OIDC provider thumbprint is current

2. **ECR Push Failures**:
   - Verify ECR repository exists and is accessible
   - Check IAM role permissions for ECR operations
   - Ensure AWS region matches ECR repository region

3. **Role Assumption Issues**:
   - Verify `aws-actions/configure-aws-credentials` action version
   - Check that `id-token: write` permission is set in workflow
   - Ensure role ARN is correctly formatted

### Debug Commands

```bash
# Test ECR authentication
aws ecr get-login-password --region us-east-1

# List ECR repositories
aws ecr describe-repositories

# Check role trust policy
aws iam get-role --role-name GitHubCDRole
```

## 📚 References

- [GitHub OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [CD-plan.md](./CD-plan.md) - Complete CD pipeline implementation guide
