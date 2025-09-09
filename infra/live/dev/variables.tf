variable "aws_region" {
  type        = string
  description = "The AWS region to deploy resources to"
  default     = "us-east-1"
}
variable "aws_profile" {
  type        = string
  description = "The AWS profile to use for authentication"
}
variable "project" { type = string }
variable "env" { type = string }
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "az_count" {
  type    = number
  default = 2
}
variable "instance_type" {
  type    = string
  default = "t3.medium"
}
variable "ec2_root_size" {
  type    = number
  default = 30
}
variable "container_port" {
  type    = number
  default = 8000
}
variable "healthcheck_path" {
  type    = string
  default = "api/health/"
}
variable "acm_certificate_arn" {
  type    = string
  default = null
}

variable "use_nat_gateway" {
  type    = bool
  default = false
}

variable "ssh_allowed_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "ssh_key_name" {
  type = string
}

# Django Environment Variables
variable "django_secret_key" {
  type        = string
  description = "Django secret key for cryptographic operations"
  default     = "cgm-your-production-secret-key-here"
  sensitive   = true
}

variable "whoop_client_secret" {
  type        = string
  description = "Whoop API client secret"
  default     = ""
  sensitive   = true
}

variable "django_env" {
  type        = string
  description = "Django environment setting"
  default     = "production"
}

variable "allowed_hosts" {
  type        = string
  description = "Django allowed hosts"
  default     = "*"
}

variable "cors_allowed_origins" {
  type        = string
  description = "CORS allowed origins"
  default     = "*"
}

variable "whoop_client_id" {
  type        = string
  description = "Whoop API client ID"
  default     = ""
}

variable "whoop_redirect_uri" {
  type        = string
  description = "Whoop OAuth redirect URI"
  default     = ""
}

variable "openai_model" {
  type        = string
  description = "OpenAI model to use"
  default     = "gpt-5-nano"
}

variable "openai_key" {
  type        = string
  description = "OpenAI API key"
  default     = ""
  sensitive   = true
}

variable "ai_analysis_interval_hours" {
  type        = string
  description = "AI analysis interval in hours"
  default     = "1"
}

variable "ai_analysis_period_days" {
  type        = string
  description = "AI analysis period in days"
  default     = "14"
}

variable "secure_ssl_redirect" {
  type        = string
  description = "Whether to force SSL redirect"
  default     = "False"
}

variable "ecr_repo_name" {
  type        = string
  description = "ECR repository name"
}

variable "use_cross_account_role" {
  type        = bool
  description = "Whether to assume cross-account role (true for mgmt users, false for dev users)"
  default     = false
}


# Frontend Configuration
variable "frontend_domain_name" {
  type        = string
  description = "Domain name for the frontend (optional)"
  default     = null
}

variable "frontend_acm_certificate_arn" {
  type        = string
  description = "ACM certificate ARN for the frontend domain (optional)"
  default     = null
}

variable "s3_bucket_name" {
  type        = string
  description = "S3 bucket name for hosting React app (must be globally unique)"
}

variable "cloudfront_price_class" {
  type        = string
  description = "CloudFront price class"
  default     = "PriceClass_100"
  validation {
    condition = contains([
      "PriceClass_All",
      "PriceClass_200",
      "PriceClass_100"
    ], var.cloudfront_price_class)
    error_message = "Price class must be PriceClass_All, PriceClass_200, or PriceClass_100."
  }
}

variable "enable_frontend_logging" {
  type        = bool
  description = "Enable CloudFront access logging"
  default     = false
}

# RDS PostgreSQL Variables
variable "postgres_version" {
  type        = string
  description = "PostgreSQL engine version"
  default     = "15.7"
}

variable "db_instance_class" {
  type        = string
  description = "RDS instance class"
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  type        = number
  description = "Initial allocated storage in GB"
  default     = 20
}

variable "db_max_allocated_storage" {
  type        = number
  description = "Maximum allocated storage in GB for autoscaling"
  default     = 100
}

variable "db_name" {
  type        = string
  description = "Database name"
  default     = "cgmdb"
}

variable "db_username" {
  type        = string
  description = "Database master username"
  default     = "cgmadmin"
}

variable "db_backup_retention_period" {
  type        = number
  description = "Backup retention period in days"
  default     = 7
}

variable "db_backup_window" {
  type        = string
  description = "Backup window"
  default     = "03:00-04:00"
}

variable "db_maintenance_window" {
  type        = string
  description = "Maintenance window"
  default     = "Sun:04:00-Sun:05:00"
}

variable "db_performance_insights_enabled" {
  type        = bool
  description = "Enable Performance Insights"
  default     = false
}

variable "db_monitoring_interval" {
  type        = number
  description = "Enhanced monitoring interval in seconds (0 to disable)"
  default     = 0
  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.db_monitoring_interval)
    error_message = "Monitoring interval must be one of: 0, 1, 5, 10, 15, 30, 60."
  }
}

variable "db_multi_az" {
  type        = bool
  description = "Enable Multi-AZ deployment for RDS (increases cost but provides HA)"
  default     = false
}

# ElastiCache Redis Variables
variable "redis_engine_version" {
  type        = string
  description = "Redis engine version"
  default     = "7.0"
}

variable "redis_node_type" {
  type        = string
  description = "Redis node type"
  default     = "cache.t3.micro"
}

variable "redis_num_cache_nodes" {
  type        = number
  description = "Number of cache nodes (1 for single-node, 2+ for HA cluster)"
  default     = 1
}

variable "redis_multi_az" {
  type        = bool
  description = "Enable Multi-AZ for Redis cluster (requires 2+ nodes, increases cost)"
  default     = false
}

variable "redis_parameter_group_name" {
  type        = string
  description = "Redis parameter group name"
  default     = "default.redis7"
}

variable "redis_transit_encryption_enabled" {
  type        = bool
  description = "Enable transit encryption"
  default     = false
}

variable "redis_auth_token_enabled" {
  type        = bool
  description = "Enable Redis AUTH token"
  default     = false
}

variable "redis_snapshot_retention_limit" {
  type        = number
  description = "Number of days to retain snapshots"
  default     = 1
}

variable "redis_snapshot_window" {
  type        = string
  description = "Snapshot window"
  default     = "03:00-05:00"
}

variable "redis_maintenance_window" {
  type        = string
  description = "Maintenance window"
  default     = "Sun:05:00-Sun:07:00"
}

variable "redis_log_delivery_configuration" {
  type = list(object({
    destination      = string
    destination_type = string
    log_format       = string
    log_type         = string
  }))
  description = "Redis log delivery configuration"
  default     = []
}