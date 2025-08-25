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

variable "database_url" {
  type        = string
  description = "Database connection URL"
  default     = ""
  sensitive   = true
}

variable "redis_url" {
  type        = string
  description = "Redis connection URL"
  default     = ""
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