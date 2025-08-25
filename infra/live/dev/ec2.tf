# Get the latest Ubuntu 24.04 LTS AMI
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

# EC2 Instance
resource "aws_instance" "app" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.ssh_key_name

  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name

  user_data = templatefile("${path.module}/user_data.sh", {
    region         = var.aws_region
    image_uri      = aws_ecr_repository.app.repository_url
    image_tag      = "latest"
    secret_arn     = aws_secretsmanager_secret.django_env.arn
    secrets_format = "json"
    container_port = var.container_port
  })

  root_block_device {
    volume_type = "gp3"
    volume_size = var.ec2_root_size
    encrypted   = true
  }

  tags = {
    Name    = "${var.project}-${var.env}-app"
    Project = var.project
    Env     = var.env
  }
}

# ECR Repository for Docker images
resource "aws_ecr_repository" "app" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name    = "${var.project}-${var.env}-ecr"
    Project = var.project
    Env     = var.env
  }
}