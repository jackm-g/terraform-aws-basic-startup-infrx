# ElastiCache Subnet Group
resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project}-${var.env}-cache-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name    = "${var.project}-${var.env}-cache-subnet-group"
    Project = var.project
    Env     = var.env
  }
}

# Security group for ElastiCache Redis
resource "aws_security_group" "redis" {
  name        = "${var.project}-${var.env}-redis-sg"
  description = "Security group for ElastiCache Redis"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
    description     = "Redis access from EC2"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name    = "${var.project}-${var.env}-redis-sg"
    Project = var.project
    Env     = var.env
  }
}

# ElastiCache Redis Cluster
resource "aws_elasticache_replication_group" "main" {
  replication_group_id       = "${var.project}-${var.env}-redis"
  description                = "Redis cluster for ${var.project} ${var.env}"

  # Redis Configuration
  engine               = "redis"
  engine_version       = var.redis_engine_version
  node_type            = var.redis_node_type
  port                 = 6379
  parameter_group_name = var.redis_parameter_group_name

  # Cluster Configuration
  num_cache_clusters = var.redis_num_cache_nodes
  
  # Network Configuration
  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.redis.id]

  # Security Configuration
  at_rest_encryption_enabled = true
  transit_encryption_enabled = var.redis_transit_encryption_enabled
  auth_token                 = var.redis_auth_token_enabled ? random_password.redis_auth_token[0].result : null

  # Backup Configuration
  snapshot_retention_limit = var.redis_snapshot_retention_limit
  snapshot_window         = var.redis_snapshot_window
  maintenance_window      = var.redis_maintenance_window

  # High Availability configuration (cost optimization)
  automatic_failover_enabled = var.redis_multi_az && var.redis_num_cache_nodes > 1 ? true : false
  multi_az_enabled          = var.redis_multi_az && var.redis_num_cache_nodes > 1 ? true : false

  # Final snapshot
  final_snapshot_identifier = var.env == "dev" ? null : "${var.project}-${var.env}-redis-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Log delivery configuration
  dynamic "log_delivery_configuration" {
    for_each = var.redis_log_delivery_configuration
    content {
      destination      = log_delivery_configuration.value.destination
      destination_type = log_delivery_configuration.value.destination_type
      log_format       = log_delivery_configuration.value.log_format
      log_type         = log_delivery_configuration.value.log_type
    }
  }

  tags = {
    Name    = "${var.project}-${var.env}-redis"
    Project = var.project
    Env     = var.env
  }
}

# Random password for Redis AUTH (if enabled)
resource "random_password" "redis_auth_token" {
  count   = var.redis_auth_token_enabled ? 1 : 0
  length  = 32
  special = false # Redis AUTH tokens should not contain special characters
}

# Store Redis auth token in Secrets Manager (if enabled)
resource "aws_secretsmanager_secret" "redis_auth_token" {
  count       = var.redis_auth_token_enabled ? 1 : 0
  name        = "${var.project}-${var.env}-redis-auth-token"
  description = "Redis AUTH token"

  tags = {
    Name    = "${var.project}-${var.env}-redis-auth-token"
    Project = var.project
    Env     = var.env
  }
}

resource "aws_secretsmanager_secret_version" "redis_auth_token" {
  count         = var.redis_auth_token_enabled ? 1 : 0
  secret_id     = aws_secretsmanager_secret.redis_auth_token[0].id
  secret_string = random_password.redis_auth_token[0].result
}
