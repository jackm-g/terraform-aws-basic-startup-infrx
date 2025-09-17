# AWS Organization & Infrastructure Terraform

This repository provides a complete Terraform setup for bootstrapping AWS Organizations and deploying basic application infrastructure. It's designed as a foundation for multi-account AWS environments with proper management and sub-accounts, like a develoment, staging, and prod account.

## Architecture Overview

This setup creates a complete AWS multi-account infrastructure with the following components:

### Infrastructure Phases

## Phase 1: Management Account Setup
```
┌─────────────────────────────────────────────────────────────┐
│                   MANAGEMENT ACCOUNT                        │
│                                                             │
│  Step 1.1: Backend Bootstrap                                │
│  ┌─────────────────────────────────────┐                   │
│  │     Management Backend              │                   │
│  │  S3: mgmt-terraform-state           │                   │
│  │  DDB: mgmt-terraform-locks          │                   │
│  └─────────────────────────────────────┘                   │
│                                                             │
│  Step 1.2: Organization & Accounts                          │
│  ├── AWS Organization (All Features)                        │
│  ├── Organizational Units                                   │
│  │   └── Workloads/                                         │
│  │       ├── Dev/                                           │
│  │       └── Prod/                                          │
│  └── Member Accounts Creation                               │
│      ├── Dev Account                                        │
│      └── Prod Account                                       │
│                                                             │
│  Step 1.3: Cross-Account Roles                              │
│  └── TerraformDeployRole in each member account             │
└─────────────────────────────────────────────────────────────┘
```

## Phase 2: Dev Account Setup
```
┌─────────────────────────────────────────────────────────────┐
│                     DEV ACCOUNT                             │
│                                                             │
│  Step 2.1: Backend Bootstrap                                │
│  ┌─────────────────────────────────────┐                   │
│  │        Dev Backend                  │                   │
│  │  S3: dev-terraform-state            │                   │
│  │  DDB: dev-terraform-locks           │                   │
│  └─────────────────────────────────────┘                   │
│                                                             │
│  Step 2.2: Application Infrastructure                       │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                VPC & Networking                         │ │
│  │  ├── VPC with Multi-AZ deployment                      │ │
│  │  ├── Public Subnets (ALB, EC2)                         │ │
│  │  ├── Private Subnets (Redis)                           │ │
│  │  └── Database Subnets (RDS)                            │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │               Backend Services                          │ │
│  │  ├── EC2 Instance (Ubuntu 24.04 + Docker)              │ │
│  │  ├── Application Load Balancer (HTTP/HTTPS)            │ │
│  │  ├── RDS PostgreSQL (Multi-AZ capable)                 │ │
│  │  ├── ElastiCache Redis (HA capable)                    │ │
│  │  └── ECR Repository (manual creation)                  │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │               Frontend Services                         │ │
│  │  ├── S3 Bucket (React app hosting)                     │ │
│  │  ├── CloudFront Distribution (CDN + SSL)               │ │
│  │  └── Origin Access Control (OAC)                       │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │            Security & Management                        │ │
│  │  ├── AWS Secrets Manager (DB passwords, tokens)        │ │
│  │  ├── Security Groups (multi-tier)                      │ │
│  │  ├── IAM Roles & Policies                              │ │
│  │  └── SSL Certificates (ACM)                            │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Optional: CI/CD Infrastructure
```
┌─────────────────────────────────────────────────────────────┐
│                CI/EC2 Infrastructure                        │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │            Self-Hosted CI Runner                        │ │
│  │  ├── EC2 Instance (GitHub Actions Runner)              │ │
│  │  ├── Docker Engine (for builds)                        │ │
│  │  ├── GitHub Token Integration                          │ │
│  │  ├── Elastic IP (stable access)                        │ │
│  │  └── Security Groups (SSH + outbound)                  │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
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

## Phase 1: Management Account Setup

### 1.1 Enable AWS Organizations

Enable AWS Organizations with all features (one-time setup):
```bash
aws organizations create-organization --feature-set ALL
```

### 1.2 Create Management Account Backend

First, configure your backend resource names in `terraform.tfvars`:
```bash
cd infra/mgmt-backend-bootstrap
# Edit terraform.tfvars - update bucket_name and dynamodb_table_name with your preferred names
# Example: bucket_name = "yourorg-mgmt-terraform-bucket"
```

Then deploy backend infrastructure:
```bash
terraform init && terraform apply
```

**Important**: After applying, note the outputs (`s3_bucket_name` and `dynamodb_table_name`) to update backend configurations.

### 1.3 Update Backend Configurations

Before proceeding, update the `backend.tf` files with the actual bucket and table names created by the bootstrap:

```bash
# Get the backend resource names
terraform output s3_bucket_name
terraform output dynamodb_table_name

# Update infra/org-bootstrap/backend.tf
# Update infra/org-roles/backend.tf
# Replace bucket and dynamodb_table values with the actual names from outputs
```

**Why**: Backend configurations are hardcoded but the actual resource names depend on your `terraform.tfvars` settings. Terraform requires the exact resource names for remote state management.

### 1.4 Deploy Organization & Accounts

Configure account emails in `terraform.tfvars` and deploy:
```bash
cd ../org-bootstrap/
terraform init && terraform apply
```

### 1.5 Create Cross-Account Deployment Roles

Deploy cross-account roles:
```bash
cd ../org-roles/
terraform init && terraform apply
```

## Phase 2: Dev Account Setup

### 2.1 Create Dev Account Backend

First, configure your backend resource names and AWS profile in `terraform.tfvars`:
```bash
cd infra/dev-backend-bootstrap
# Edit terraform.tfvars - update:
# - profile = "your-dev-aws-profile"
# - bucket_name = "yourorg-dev-terraform-bucket" 
# - dynamodb_table_name = "yourorg-dev-terraform-table"
```

Then deploy backend infrastructure:
```bash
terraform init && terraform apply
```

**Important**: After applying, note the outputs (`s3_bucket_name` and `dynamodb_table_name`) to update dev backend configurations.

### 2.2 Update Dev Backend Configurations

Update the `backend.tf` files in dev environments with the actual bucket and table names:

```bash
# Get the backend resource names
terraform output s3_bucket_name
terraform output dynamodb_table_name

# Update infra/live/dev/backend.tf
# Update infra/live/ci-ec2/backend.tf (if using)
# Replace bucket and dynamodb_table values with the actual names from outputs
```

### 2.3 Create EC2 Key Pair

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

### 2.4 Build and Push Docker Image to ECR

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

### 2.5 Deploy Dev Application Infrastructure

Configure variables in `terraform.tfvars` and deploy:
```bash
cd ../live/dev/
# Update terraform.tfvars with your configuration
terraform init && terraform apply
```

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

The infrastructure can use custom domains with SSL certificates. You can set this up in either your dev account (recommended for simplicity) or use a multi-account setup.


#### 1. **Domain Registration & Route 53**
- Register your domain (e.g., `yourdomain.com`) or transfer to Route 53
- Create hosted zone in your **dev account** Route 53
- Note the hosted zone ID for DNS record creation

#### 2. **SSL Certificates (ACM)**
Request certificates in your **dev account**:
```bash
# Request certificate for your domain and subdomains
aws acm request-certificate \
  --domain-name yourdomain.com \
  --subject-alternative-names "*.yourdomain.com" \
  --validation-method DNS \
  --region <REGION> \
  --profile <AWS_PROFILE>
```

#### 3. **DNS Validation**
- Go to ACM console and copy the DNS validation CNAME records
- Add these CNAME records to your Route 53 hosted zone
- Wait for certificate validation (usually takes a few minutes)

#### 4. **Update terraform.tfvars**
```hcl
# Use the same certificate for both frontend and backend
acm_certificate_arn = "arn:aws:acm:region:account-id:certificate/your-cert-id"
frontend_acm_certificate_arn = "arn:aws:acm:region:account-id:certificate/your-cert-id"
frontend_domain_name = "www.yourdomain.com"
```

#### 5. **Create DNS Records After Deployment**
After running `terraform apply`, create DNS records in Route 53:
```bash
# Get ALB and CloudFront endpoints from Terraform outputs
terraform output alb_dns_name
terraform output cloudfront_domain_name
terraform output cloudfront_redirect_domain_name
```

**Manual Route 53 Configuration (AWS Console):**

1. **For www subdomain (main site):**
   - Record type: `CNAME`
   - Name: `www.yourdomain.com`
   - Value: Use `cloudfront_domain_name` output from Terraform

2. **For apex domain (redirect to www):**
   - Record type: `A` 
   - Name: `yourdomain.com` (leave empty for root domain)
   - Alias: Yes
   - Value: Use `cloudfront_redirect_domain_name` output from Terraform
   - Route traffic to: CloudFront distribution

3. **For API subdomain (optional):**
   - Record type: `CNAME`
   - Name: `api.yourdomain.com`
   - Value: Use `alb_dns_name` output from Terraform

**Note**: For enterprise environments, you can manage DNS in the management account instead (domain and certificates in **management account**, infrastructure in **dev account**). In this case, you'll need to update Route 53 and ACM in the AWS management account rather than the dev account.

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