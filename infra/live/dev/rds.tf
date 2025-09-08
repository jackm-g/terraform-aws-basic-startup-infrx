# RDS Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-${var.env}-db-subnet-group"
  subnet_ids = module.vpc.database_subnets

  tags = {
    Name    = "${var.project}-${var.env}-db-subnet-group"
    Project = var.project
    Env     = var.env
  }
}

# Security group for RDS
resource "aws_security_group" "rds" {
  name        = "${var.project}-${var.env}-rds-sg"
  description = "Security group for RDS PostgreSQL database"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
    description     = "PostgreSQL access from EC2"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name    = "${var.project}-${var.env}-rds-sg"
    Project = var.project
    Env     = var.env
  }
}

# Random password for RDS
resource "random_password" "db_password" {
  length  = 16
  special = true
  # Exclude characters that are not allowed in RDS passwords
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "main" {
  identifier = "${var.project}-${var.env}-postgres"

  engine         = "postgres"
  engine_version = var.postgres_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  
  # Multi-AZ configuration (cost optimization)
  multi_az = var.db_multi_az

  backup_retention_period = var.db_backup_retention_period
  backup_window          = var.db_backup_window
  maintenance_window     = var.db_maintenance_window

  skip_final_snapshot       = var.env == "dev" ? true : false
  final_snapshot_identifier = var.env == "dev" ? null : "${var.project}-${var.env}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  deletion_protection       = var.env == "prod" ? true : false

  # Enable automated backups
  delete_automated_backups = true

  # Performance Insights
  performance_insights_enabled = var.db_performance_insights_enabled
  
  # Monitoring
  monitoring_interval = var.db_monitoring_interval
  monitoring_role_arn = var.db_monitoring_interval > 0 ? aws_iam_role.rds_enhanced_monitoring[0].arn : null

  tags = {
    Name    = "${var.project}-${var.env}-postgres"
    Project = var.project
    Env     = var.env
  }
}

# IAM role for RDS Enhanced Monitoring
resource "aws_iam_role" "rds_enhanced_monitoring" {
  count = var.db_monitoring_interval > 0 ? 1 : 0
  name  = "${var.project}-${var.env}-rds-enhanced-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name    = "${var.project}-${var.env}-rds-enhanced-monitoring"
    Project = var.project
    Env     = var.env
  }
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  count      = var.db_monitoring_interval > 0 ? 1 : 0
  role       = aws_iam_role.rds_enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Store database password in Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name        = "${var.project}-${var.env}-db-password"
  description = "RDS PostgreSQL database password"

  tags = {
    Name    = "${var.project}-${var.env}-db-password"
    Project = var.project
    Env     = var.env
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}
