# AWS Organization & Infrastructure Terraform

This repository provides a complete Terraform setup for bootstrapping AWS Organizations and deploying basic application infrastructure. It's designed as a foundation for multi-account AWS environments with proper governance and deployment patterns.

## Architecture Overview

This setup creates a complete AWS multi-account infrastructure:

```
Management Account
├── AWS Organization (All Features)
├── Organizational Units
│   └── Workloads/
│       ├── Dev/
│       └── Prod/
└── Member Accounts (Dev, Prod)
    ├── TerraformDeployRole (for CI/CD)
    ├── VPC with public/private/database subnets
    ├── Application Load Balancer
    ├── EC2 instances with Docker
    ├── ECR repositories
    └── AWS Secrets Manager
```

## 📁 Directory Structure

```
infra/
├── org-bootstrap/    # Stage 1: AWS Organization, OUs, and member accounts
├── org-roles/        # Stage 2: Cross-account deployment roles
└── live/
    └── dev/          # Stage 3: Application infrastructure (example)
        ├── vpc.tf           # VPC with subnets across AZs
        ├── ec2.tf           # EC2 instances + ECR repository
        ├── alb.tf           # Application Load Balancer
        ├── security_groups.tf # Security groups for ALB + EC2
        ├── iam.tf           # IAM roles for EC2
        ├── secrets.tf       # AWS Secrets Manager
        └── user_data.sh     # Bootstrap script for Docker deployment
```

## 🚀 Quick Start

### Prerequisites

Before deploying, ensure you have:

1. **AWS CLI configured** with credentials for your management account
2. **Terraform >= 1.12.0** installed
3. **Appropriate IAM permissions** in the management account:
   - `organizations:*`
   - `iam:*`
   - `sts:AssumeRole`
   - `ec2:*`, `elasticloadbalancing:*`, `secretsmanager:*`, etc.

### Step 1: Manual Prerequisites

#### 1.1 Enable AWS Organizations

Log into AWS Console on your management account and enable organizations.

Or, you can also try the following from the CLI if you are logged in there:
```bash
# Enable AWS Organizations with all features (one-time setup)
aws organizations create-organization --feature-set ALL
```

#### 1.2 Create Terraform Backend

```bash
# Create unique S3 bucket for Terraform state
BUCKET_NAME="your-org-terraform-state-$(date +%s)"
aws s3 mb s3://$BUCKET_NAME --region us-east-1
aws s3api put-bucket-versioning --bucket $BUCKET_NAME --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket $BUCKET_NAME --server-side-encryption-configuration '{
  "Rules": [
    {
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }
  ]
}'

# Create DynamoDB table for state locking
TABLE_NAME="your-org-terraform-locks"
aws dynamodb create-table \
  --table-name $TABLE_NAME \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

#### 1.3 Create EC2 Key Pair (for application infrastructure)

```bash
# Create EC2 key pair for SSH access
KEY_NAME="your-app-key"
aws ec2 create-key-pair \
  --key-name $KEY_NAME \
  --query 'KeyMaterial' \
  --output text > $KEY_NAME.pem

chmod 400 $KEY_NAME.pem

# Add to .gitignore to avoid committing private keys
echo "*.pem" >> .gitignore
```

### Step 2: Configure Variables

#### 2.1 Configure Organization Bootstrap

Create `org-bootstrap/terraform.tfvars`:

```hcl
region  = "us-east-1"
profile = "your-aws-profile"  # Your AWS CLI profile for management account

account_emails = {
  dev  = "aws-dev@yourcompany.com"
  prod = "aws-prod@yourcompany.com"
}
```

#### 2.2 Update Backend Configuration

Update the backend configuration in each stage:

```hcl
# org-bootstrap/backend.tf
terraform {
  backend "s3" {
    bucket         = "your-org-terraform-state-xxxxx"  # Your bucket name
    key            = "org-bootstrap/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "your-org-terraform-locks"       # Your table name
    encrypt        = true
  }
}
```

### Step 3: Deploy Infrastructure

#### Stage 1: Create Organization & Accounts

```bash
cd org-bootstrap/

# Initialize and deploy organization structure
terraform init
terraform plan
terraform apply

# Note the account IDs from outputs - you'll need these for Stage 2
terraform output
```

**What gets created:**
- AWS Organization with "All Features" enabled
- Organizational Units: `Workloads/Dev` and `Workloads/Prod`
- Member accounts (DEV and PROD) with `OrganizationAccountAccessRole`

#### Stage 2: Create Cross-Account Deployment Roles

```bash
cd ../org-roles/

# Update backend.tf with your bucket/table names
# Initialize and deploy cross-account roles
terraform init
terraform plan
terraform apply
```

**What gets created:**
- `TerraformDeployRole` in each member account
- Trust policy allowing management account to assume these roles
- `AdministratorAccess` policy attached (consider tightening for production)

#### Stage 3: Deploy Application Infrastructure

```bash
cd ../live/dev/

# Create terraform.tfvars
cat > terraform.tfvars << EOF
aws_region   = "us-east-1"
aws_profile  = "your-aws-profile"
project      = "your-project"
env          = "dev"
ssh_key_name = "your-app-key"
ecr_repo_name = "your-app"

# Application-specific variables
django_secret_key = "your-secret-key-here"
database_url     = "sqlite:///db.sqlite3"  # or your database URL
redis_url        = ""                      # optional
EOF

# Initialize and deploy application infrastructure
terraform init
terraform plan
terraform apply
```

**What gets created:**
- VPC with public, private, and database subnets across multiple AZs
- Internet Gateway and NAT Gateway (optional)
- Application Load Balancer with HTTPS listener
- Security Groups for ALB and EC2
- EC2 instance with Docker pre-installed
- ECR repository for container images
- IAM roles for EC2 to access ECR and Secrets Manager
- AWS Secrets Manager secret for application configuration

## Customization

### Adding More AWS Accounts

1. Update `account_emails` in `org-bootstrap/terraform.tfvars`
2. Add corresponding OUs in `org-bootstrap/main.tf`
3. Add provider configurations in `org-roles/providers.tf`
4. Add role resources in `org-roles/main.tf`

### Application Configuration

The EC2 instance comes with a user data script that:
- Installs Docker and AWS CLI
- Pulls container images from ECR
- Retrieves application secrets from AWS Secrets Manager
- Starts your application container

Customize `user_data.sh` for your specific application needs.


### Verification Commands

```bash
# Verify organization structure
aws organizations list-accounts
aws organizations list-organizational-units-for-parent --parent-id r-xxxx

# Verify roles were created
aws sts assume-role --role-arn "arn:aws:iam::ACCOUNT-ID:role/TerraformDeployRole" --role-session-name test

# Verify infrastructure
aws ec2 describe-instances --filters "Name=tag:Project,Values=your-project"
aws elbv2 describe-load-balancers
aws ecr describe-repositories
```

## Additional Resources

- [AWS Organizations Best Practices](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_best-practices.html)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Multi-Account Architecture](https://aws.amazon.com/organizations/)