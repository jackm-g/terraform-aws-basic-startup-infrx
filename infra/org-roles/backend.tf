terraform {
  backend "s3" {
    bucket         = "cgm-mgmt-terraform-bucket"
    key            = "org-roles/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "cgm-mgmt-terraform-table"
    encrypt        = true
  }
}
