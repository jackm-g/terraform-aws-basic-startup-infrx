terraform {
  backend "s3" {
    bucket         = "cgm-dev-terraform-bucket"
    key            = "live/ci-ec2/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "cgm-dev-terraform-table"
    encrypt        = true
  }
}
