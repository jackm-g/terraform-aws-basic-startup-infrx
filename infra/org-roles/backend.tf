terraform {
  backend "s3" {
    bucket         = "cgm-mgmt-terraform-state"
    key            = "org-roles/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "cgm-mgmt-terraform-locks"
    encrypt        = true
  }
}
