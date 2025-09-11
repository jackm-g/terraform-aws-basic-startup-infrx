# infra/org-roles/variables.tf
variable "region" {
  description = "AWS region"
  type        = string  
  default     = "us-east-1"
}

variable "profile" {
  description = "AWS profile"
  type        = string
}

variable "tfstate_bucket" {
  description = "S3 bucket for Terraform state"
  type        = string
}
