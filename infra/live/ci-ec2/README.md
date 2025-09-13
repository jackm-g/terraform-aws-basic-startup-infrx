# CI EC2 Runner

This Terraform configuration deploys a self-hosted GitHub Actions runner on AWS EC2 for continuous integration.

## Prerequisites

1. **GitHub Personal Access Token**: You need a GitHub PAT with `repo` and `admin:repo_hook` permissions.
2. **AWS Credentials**: Configured with appropriate permissions.
3. **AWS Key Pair**: An existing EC2 key pair for SSH access.

## Setup Instructions

### 1. Update terraform.tfvars

Edit `terraform.tfvars` and update the following required values:

- `github_repo`: Your GitHub repository (format: `owner/repo`)
- `key_name`: Your AWS EC2 key pair name
- `allowed_ssh_cidrs`: Your public IP address for SSH access
- `env_file_content`: Environment variables for your tests

### 2. Set GitHub Token

Set your GitHub token as an environment variable:

```bash
export TF_VAR_github_token="your_github_personal_access_token"
```

### 3. Deploy

```bash
terraform init
terraform plan
terraform apply
```

## What Gets Created

- **EC2 Instance**: t3.large instance with Docker and Node.js in your default VPC
- **Security Group**: SSH access from specified IPs  
- **IAM Role**: For potential AWS integrations
- **Elastic IP**: Stable public IP address
- **GitHub Actions Runner**: Self-hosted runner registered to your repo

The configuration automatically uses your AWS account's default VPC and subnet, so no VPC setup is required.

## Runner Features

- **Ubuntu 22.04 LTS** with latest security updates
- **Docker & Docker Compose** for containerized builds
- **Node.js LTS** for frontend builds
- **50GB encrypted storage** for build artifacts
- **Automatic service monitoring** with restart capability
- **Log rotation** for runner logs

## Access

After deployment, you can SSH to the runner:

```bash
ssh -i /path/to/cgm-dev-app-key.pem ubuntu@$(terraform output -raw instance_public_ip)
```

## Environment File

The runner includes a test environment file at `/opt/cgm/.env.test` with your specified environment variables. This file is accessible to the runner user for CI tests.

## Monitoring

- Runner service status: `systemctl status actions.runner.*`
- Runner logs: `/opt/actions-runner/_diag/`
- Setup log: `/var/log/runner-setup.log`
- Monitor log: `/var/log/runner-monitor.log`

## Cleanup

To destroy the CI runner:

```bash
terraform destroy
```

Note: This will also unregister the runner from GitHub.
