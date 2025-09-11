# AWS Organization & Infrastructure Terraform

This repository provides a complete Terraform setup for bootstrapping AWS Organizations and deploying basic application infrastructure. It's designed as a foundation for multi-account AWS environments with proper management and development accounts.

## Architecture Overview

This setup creates a complete AWS multi-account infrastructure with the following components:

### Account Structure
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
│  ├── Route 53 Hosted Zone           │
│  │   ├── yourdomain.com             │
│  │   ├── www.yourdomain.com         │
│  │   └── api.yourdomain.com         │
│  ├── Organizational Units           │
│  │   └── Workloads/                 │
│  │       ├── Dev/                   │
│  │       └── Prod/                  │
│  └── Cross-Account Roles            │
└─────────────────────────────────────┘
                    │
                    │ DNS Resolution
                    │ Cross-account
                    ▼
┌─────────────────────────────────────┐
│           DEV ACCOUNT               │
│  ┌─────────────────────────────────┐ │
│  │        Dev Backend              │ │
│  │  S3: dev-terraform-state        │ │
│  │  DDB: dev-terraform-locks       │ │
│  └─────────────────────────────────┘ │
│                                     │
│  ├── VPC with Multi-AZ subnets      │
│  ├── Application Load Balancer      │
│  ├── EC2 instances with Docker      │
│  ├── ECR repositories               │
│  ├── CloudFront Distribution        │
│  ├── S3 Frontend Bucket             │
│  └── AWS Secrets Manager            │
└─────────────────────────────────────┘
```

## Prerequisites

Before deploying, ensure you have:

1. **AWS CLI configured** with SSO profiles (see AWS SSO Setup section below)
2. **Terraform >= 1.12.0** installed
3. **Appropriate IAM permissions**:
   - **Management Account**: `organizations:*`, `iam:*`, `sts:AssumeRole`
   - **Dev Account**: Standard resource permissions (`ec2:*`, `elasticloadbalancing:*`, etc.)
4. **EC2 Key Pair** created in the target account for SSH access
5. **Domain and SSL certificates** configured manually (see Domain & SSL Setup section below)

## User Types

- **Management Account Users**: Deploy organization infrastructure and can assume roles to deploy to member accounts
- **Dev Account Users**: Deploy directly to dev account using dev account credentials

## Phase 1: Management Account Setup (Administrators)

### 1.1 Enable AWS Organizations

Enable AWS Organizations with all features (one-time setup):
```bash
aws organizations create-organization --feature-set ALL
```

### 1.2 Create Management Account Backend

Deploy backend infrastructure for management account:
```bash
cd infra/mgmt-backend-bootstrap
terraform init && terraform apply
```

### 1.3 Deploy Organization & Accounts

Configure account emails in `terraform.tfvars` and deploy:
```bash
cd ../org-bootstrap/
terraform init && terraform apply
```

### 1.4 Create Cross-Account Deployment Roles

Deploy cross-account roles:
```bash
cd ../org-roles/
terraform init && terraform apply
```

## Phase 2: Dev Account Setup (Developers)

### 2.1 Create Dev Account Backend

Update `terraform.tfvars` with your dev account profile and deploy:
```bash
cd infra/dev-backend-bootstrap
terraform init && terraform apply
```

### 2.2 Create EC2 Key Pair

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

### 2.3 Build and Push Docker Image to ECR

**IMPORTANT**: Before deploying infrastructure, you must push a Docker image to ECR. The EC2 instance will try to pull your application image immediately upon startup.

First, create the ECR repository manually (Terraform will manage it after initial creation):
```bash
# Get your ECR repository name from terraform.tfvars
# Example: ecr_repo_name = "cgm-django-backend"

# Create ECR repository
aws ecr create-repository \
  --repository-name <ECR_REPO_NAME> \
  --region <REGION> \
  --profile <AWS_PROFILE>
```

Then build and push your Docker image:
```bash
# Navigate to your application directory
cd /path/to/your/application

# Login to ECR (replace with your actual values)
aws ecr get-login-password --region <REGION> --profile <AWS_PROFILE> | \
  docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com

# Build for linux/amd64 (required for EC2)
docker buildx build --platform linux/amd64 -t <YOUR_APP_NAME> .

# Tag for ECR (use the same repo name from terraform.tfvars)
docker tag <YOUR_APP_NAME>:latest <ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/<ECR_REPO_NAME>:latest

# Push to ECR
docker push <ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/<ECR_REPO_NAME>:latest
```

**Note**: Terraform will reference the existing ECR repository but will not manage it directly. The repository should be created manually before running terraform apply.

### 2.4 Deploy Dev Application Infrastructure

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

## Docker Image Updates

### Updating Your Application

After your initial deployment, when you need to update your application:

```bash
# Navigate to your project directory
cd /path/to/your/project

# Build and push updated image
docker buildx build --platform linux/amd64 -t <IMAGE_NAME> .
docker tag <IMAGE_NAME>:latest <ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/<ECR_REPO_NAME>:latest
docker push <ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/<ECR_REPO_NAME>:latest
```

### Restart Services After Deploy

```bash
# SSH to EC2 and restart services
ssh -i ~/.ssh/<KEY_NAME> ubuntu@<EC2_IP>
sudo systemctl restart django celery-worker celery-beat
sudo journalctl -u django -f
```

## Domain & SSL Setup

### Manual Configuration Required

The infrastructure assumes you have a domain and SSL certificates configured. These must be set up manually:

#### 1. **Domain Registration & Route 53**
- Register your domain (e.g., `yourdomain.com`) or transfer to Route 53
- Create hosted zone in **management account** Route 53
- Note the hosted zone ID for DNS record creation

#### 2. **SSL Certificates (ACM)**
- **Management Account**: Request certificate for your domain (e.g., `yourdomain.com`)
- **Dev Account**: Request wildcard certificate (e.g., `*.yourdomain.com`) for backend services
- Use **DNS validation** and add CNAME records to management account Route 53
- Update `terraform.tfvars` with certificate ARNs

#### 3. **DNS Records (Manual Creation)**
After deploying infrastructure, manually create these Route 53 records in **management account**:

```bash
# Get ALB and CloudFront endpoints from Terraform outputs
terraform output alb_dns_name
terraform output cloudfront_domain_name

# Create A records (Alias) in Route 53:
# www.yourdomain.com → CloudFront distribution
# api.yourdomain.com → Application Load Balancer
```

#### 4. **Update terraform.tfvars**
```hcl
# Use certificate ARNs from respective accounts
acm_certificate_arn = "arn:aws:acm:region:dev-account:certificate/wildcard-cert-id"
frontend_acm_certificate_arn = "arn:aws:acm:region:dev-account:certificate/www-cert-id"
frontend_domain_name = "www.yourdomain.com"
```

**Note**: This multi-account DNS setup (domain in management, infrastructure in dev) is a best practice for enterprise environments.

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
   
## Additional Resources

- [AWS Organizations Best Practices](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_best-practices.html)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Multi-Account Architecture](https://aws.amazon.com/organizations/)