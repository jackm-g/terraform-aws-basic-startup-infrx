# modules/ci-runner/variables.tf
variable "instance_type" {
  description = "EC2 instance type for the CI runner"
  type        = string
  default     = "t3.large"
}

variable "key_name" {
  description = "AWS Key Pair name for SSH access"
  type        = string
}

variable "use_default_vpc" {
  description = "Use the default VPC and subnet"
  type        = bool
  default     = true
}

variable "subnet_id" {
  description = "Subnet ID where the CI runner will be deployed (optional if using default VPC)"
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "VPC ID for security group creation (optional if using default VPC)"
  type        = string
  default     = null
}

variable "github_token" {
  description = "GitHub Personal Access Token for runner registration"
  type        = string
  sensitive   = true
}

variable "github_repo" {
  description = "GitHub repository in format owner/repo"
  type        = string
}

variable "runner_name" {
  description = "Name for the GitHub Actions runner"
  type        = string
  default     = "cgm-ci-runner"
}

variable "env_file_content" {
  description = "Content of the .env.test file for CI tests"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH to the instance"
  type        = list(string)
  default     = []
}

# modules/ci-runner/main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data sources
data "aws_vpc" "default" {
  count   = var.use_default_vpc ? 1 : 0
  default = true
}

data "aws_subnets" "default" {
  count = var.use_default_vpc ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default[0].id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# Data source for the latest Ubuntu 24
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security group for the CI runner
resource "aws_security_group" "ci_runner" {
  name_prefix = "${var.runner_name}-"
  description = "Security group for GitHub Actions CI runner"
  vpc_id      = var.use_default_vpc ? data.aws_vpc.default[0].id : var.vpc_id

  # SSH access
  dynamic "ingress" {
    for_each = length(var.allowed_ssh_cidrs) > 0 ? [1] : []
    content {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.allowed_ssh_cidrs
    }
  }

  # All outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.runner_name}-sg"
  })
}

# IAM role for the CI runner (for potential future AWS integrations)
resource "aws_iam_role" "ci_runner" {
  name = "${var.runner_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM instance profile
resource "aws_iam_instance_profile" "ci_runner" {
  name = "${var.runner_name}-profile"
  role = aws_iam_role.ci_runner.name

  tags = var.tags
}

# User data script for CI runner setup
locals {
  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    github_token    = var.github_token
    github_repo     = var.github_repo
    runner_name     = var.runner_name
    env_file_content = var.env_file_content
  }))
}

# EC2 instance for the CI runner
resource "aws_instance" "ci_runner" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name              = var.key_name
  subnet_id             = var.use_default_vpc ? data.aws_subnets.default[0].ids[0] : var.subnet_id
  vpc_security_group_ids = [aws_security_group.ci_runner.id]
  iam_instance_profile   = aws_iam_instance_profile.ci_runner.name

  # Increased storage for Docker images and build artifacts
  root_block_device {
    volume_type = "gp3"
    volume_size = 50
    encrypted   = true
    
    tags = merge(var.tags, {
      Name = "${var.runner_name}-root-volume"
    })
  }

  user_data = local.user_data

  tags = merge(var.tags, {
    Name = var.runner_name
    Type = "GitHub-Actions-Runner"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Elastic IP for stable public access (optional)
resource "aws_eip" "ci_runner" {
  instance = aws_instance.ci_runner.id
  domain   = "vpc"

  tags = merge(var.tags, {
    Name = "${var.runner_name}-eip"
  })

  depends_on = [aws_instance.ci_runner]
}

# Outputs
output "instance_id" {
  description = "ID of the CI runner EC2 instance"
  value       = aws_instance.ci_runner.id
}

output "instance_public_ip" {
  description = "Public IP address of the CI runner"
  value       = aws_eip.ci_runner.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the CI runner"
  value       = aws_instance.ci_runner.private_ip
}

output "security_group_id" {
  description = "ID of the security group for the CI runner"
  value       = aws_security_group.ci_runner.id
}

output "ssh_command" {
  description = "SSH command to connect to the runner"
  value       = "ssh -i /path/to/${var.key_name}.pem ubuntu@${aws_eip.ci_runner.public_ip}"
}
