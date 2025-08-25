# infra/org-bootstrap/variables.tf
variable "region" {
  description = "AWS region"
  type        = string  
  default     = "us-east-1"
}

variable "profile" {
  description = "AWS profile"
  type        = string
}

variable "account_emails" {
  description = "Email addresses for AWS accounts"
  type = object({
    dev  = string
    prod = string
  })
}
