# AWS Organization & Infrastructure Terraform

This repository provides a complete Terraform setup for bootstrapping AWS Organizations and deploying basic application infrastructure. It's designed as a foundation for multi-account AWS environments with proper governance, deployment patterns, and **decoupled backend infrastructure** for management and development accounts.

## Architecture Overview

This setup creates a complete AWS multi-account infrastructure with **decoupled backend systems**:

```
┌─────────────────────────────────────┐
│         MANAGEMENT ACCOUNT          │
│  ┌─────────────────────────────────┐ │
│  │     Management Backend          │ │
│  │  S3: mgmt-terraform-state       │ │
│  │  DDB: mgmt-terraform-locks      │ │
│  └─────────────────────────────────┘ │
│                                     │
│  ├── AWS Organization (All Features) │
│  ├── Organizational Units           │
│  │   └── Workloads/                 │
│  │       ├── Dev/                   │
│  │       └── Prod/                  │
│  └── Cross-Account Roles            │
└─────────────────────────────────────┘
                    │
                    │ Cross-account
                    │ role assumption
                    ▼
┌─────────────────────────────────────┐
│           DEV ACCOUNT               │
│  ┌─────────────────────────────────┐ │
│  │        Dev Backend              │ │
│  │  S3: dev-terraform-state        │ │
│  │  DDB: dev-terraform-locks       │ │
│  └─────────────────────────────────┘ │
│                                     │
│  ├── VPC with subnets across AZs    │
│  ├── Application Load Balancer      │
│  ├── EC2 instances with Docker      │
│  ├── ECR repositories               │
│  └── AWS Secrets Manager            │
└─────────────────────────────────────┘
```

## 📁 Directory Structure

```
infra/
├── mgmt-backend-bootstrap/  # Backend infrastructure for management account
├── dev-backend-bootstrap/   # Backend infrastructure for dev account
├── org-bootstrap/          # Stage 1: AWS Organization, OUs, and member accounts
├── org-roles/              # Stage 2: Cross-account deployment roles
└── live/
    └── dev/                # Stage 3: Application infrastructure (example)
        ├── vpc.tf                # VPC with subnets across AZs
        ├── ec2.tf                # EC2 instances + ECR repository
        ├── alb.tf                # Application Load Balancer
        ├── security_groups.tf    # Security groups for ALB + EC2
        ├── iam.tf                # IAM roles for EC2
        ├── secrets.tf            # AWS Secrets Manager
        └── user_data.sh          # Bootstrap script for Docker deployment
```

## 🚀 Quick Start

This setup uses **decoupled backends** - management and dev accounts have separate Terraform state infrastructure. See [SETUP.md](SETUP.md) for detailed deployment instructions.

### Prerequisites

Before deploying, ensure you have:

1. **AWS CLI configured** with SSO profiles (see AWS SSO Setup section below)
2. **Terraform >= 1.12.0** installed
3. **Appropriate IAM permissions**:
   - **Management Account**: `organizations:*`, `iam:*`, `sts:AssumeRole`
   - **Dev Account**: Standard resource permissions (`ec2:*`, `elasticloadbalancing:*`, etc.)
4. **EC2 Key Pair** created in the target account for SSH access

### User Types

- **Management Account Users**: Deploy organization infrastructure and can assume roles to deploy to member accounts
- **Dev Account Users**: Deploy directly to dev account using dev account credentials

### Phase 1: Management Account Setup (Administrators)

#### 1.1 Enable AWS Organizations

Enable AWS Organizations with all features (one-time setup):
```bash
aws organizations create-organization --feature-set ALL
```

#### 1.2 Create Management Account Backend

Deploy backend infrastructure for management account:
```bash
cd infra/mgmt-backend-bootstrap
terraform init && terraform apply
```

#### 1.3 Deploy Organization & Accounts

Configure account emails in `terraform.tfvars` and deploy:
```bash
cd ../org-bootstrap/
terraform init && terraform apply
```

#### 1.4 Create Cross-Account Deployment Roles

Deploy cross-account roles:
```bash
cd ../org-roles/
terraform init && terraform apply
```

### Phase 2: Dev Account Setup (Developers)

#### 2.1 Create Dev Account Backend

Update `terraform.tfvars` with your dev account profile and deploy:
```bash
cd infra/dev-backend-bootstrap
terraform init && terraform apply
```

#### 2.2 Create EC2 Key Pair

Create a key pair for SSH access to EC2 instances:
```bash
# Option 1: Create new key pair in AWS
aws ec2 create-key-pair \
  --key-name your-app-key \
  --query 'KeyMaterial' \
  --output text > your-app-key.pem
chmod 400 your-app-key.pem

# Option 2: Import existing public key
# (First generate public key from private key if needed)
ssh-keygen -y -f your-private-key.pem > your-public-key.pub
aws ec2 import-key-pair \
  --key-name your-app-key \
  --public-key-material fileb://your-public-key.pub
```

#### 2.3 Deploy Dev Application Infrastructure

Configure variables in `terraform.tfvars` and deploy:
```bash
cd ../live/dev/
# Update terraform.tfvars with your configuration
terraform init && terraform apply
```

## What Gets Created

### Management Account Infrastructure
- **Backend**: S3 bucket and DynamoDB table for management account state
- **Organization**: AWS Organization with "All Features" enabled
- **OUs**: Organizational Units (`Workloads/Dev`, `Workloads/Prod`)
- **Accounts**: Member accounts (DEV and PROD) with `OrganizationAccountAccessRole`
- **Roles**: `TerraformDeployRole` in each member account with trust to management account

### Dev Account Infrastructure  
- **Backend**: S3 bucket and DynamoDB table for dev account state
- **VPC**: Public, private, and database subnets across multiple AZs
- **Networking**: Internet Gateway and optional NAT Gateway
- **Load Balancer**: Application Load Balancer with HTTPS listener
- **Security**: Security Groups for ALB and EC2
- **Compute**: EC2 instance with Docker pre-installed
- **Container Registry**: ECR repository for container images
- **Secrets**: AWS Secrets Manager for application configuration
- **IAM**: Roles for EC2 to access ECR and Secrets Manager

## Key Benefits

✅ **Decoupled Backends**: Management and dev accounts have separate state infrastructure  
✅ **Flexible Access**: Supports both management account users and direct dev account users  
✅ **Proper Security**: Each account controls its own backend and resources  
✅ **Scalable Architecture**: Easy to add more environments (staging, prod, etc.)  
✅ **Cross-Account References**: Dev infrastructure can reference management account roles

## Customization

### Adding More AWS Accounts

1. **Update org-bootstrap**: Add new account emails in `terraform.tfvars`
2. **Update org-roles**: Add new provider configurations and role resources
3. **Create new backend bootstrap**: Copy `dev-backend-bootstrap` for new account
4. **Create new live environment**: Copy `live/dev` for new environment

### Application Configuration

The EC2 instance includes a user data script that:
- Installs Docker and AWS CLI
- Pulls container images from ECR
- Retrieves application secrets from AWS Secrets Manager
- Starts your application container

Customize `user_data.sh` for your specific application needs.


## AWS SSO Setup

### Setting Up AWS SSO Profiles

1. **Configure Management Account SSO**:
   ```bash
   aws configure sso
   # SSO session name: your-mgmt-sso
   # SSO start URL: https://your-sso-domain.awsapps.com/start
   # Account: Your management account ID
   # Role: AdministratorAccess
   # Profile name: your-mgmt-profile
   ```

2. **Configure Dev Account SSO**:
   - First, assign yourself to the dev account in AWS SSO console
   - Then configure the profile:
   ```bash
   aws configure sso
   # SSO session name: your-dev-sso
   # Account: Your dev account ID
   # Role: AdministratorAccess
   # Profile name: your-dev-profile
   ```

3. **Login to Accounts**:
   ```bash
   aws sso login --profile your-mgmt-profile
   aws sso login --profile your-dev-profile
   ```

## Verification Commands

### Verify Account Access
```bash
# Check management account
aws sts get-caller-identity --profile your-mgmt-profile

# Check dev account
aws sts get-caller-identity --profile your-dev-profile

# List organization accounts
aws organizations list-accounts --profile your-mgmt-profile
```

### Verify Infrastructure
```bash
# Verify backend access
aws s3 ls s3://cgm-dev-terraform-state/ --profile your-dev-profile

# Verify deployed resources
aws ec2 describe-instances --profile your-dev-profile
aws elbv2 describe-load-balancers --profile your-dev-profile
```

## Troubleshooting

### Authentication Issues
- **"Profile not found"**: Run `aws configure sso` to create the profile
- **403 Forbidden on S3**: Ensure you're using the correct AWS profile for the account
- **SSO session expired**: Run `aws sso login --profile your-profile`

### Terraform Backend Issues
- **Backend configuration changed**: Use `terraform init -reconfigure`
- **State file access denied**: Verify you're in the correct account and have the right permissions
- **Cross-account state access fails**: Ensure `use_cross_account_role` is set correctly in `terraform.tfvars`

### Infrastructure Deployment
- **Key pair not found**: Create or import the EC2 key pair in the target account
- **Role assumption fails**: Verify TerraformDeployRole exists and SSO session is active
- **Backend not found**: Ensure backend bootstrap was deployed in the correct account

### Profile Configuration Issues
- **Wrong account when planning**: Check `aws sts get-caller-identity --profile your-profile`
- **Cross-account access**: Set `use_cross_account_role = false` for direct account access
- **Remote state access**: Management account users need access to management backend for org-roles state

For detailed troubleshooting and advanced configuration, see [SETUP.md](SETUP.md).

## Additional Resources

- [Detailed Setup Guide](SETUP.md) - Comprehensive deployment and configuration guide
- [AWS Organizations Best Practices](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_best-practices.html)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Multi-Account Architecture](https://aws.amazon.com/organizations/)