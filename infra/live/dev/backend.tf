terraform {
  backend "s3" {
    bucket         = "cgm-dev-terraform-state"
    key            = "live/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "cgm-dev-terraform-locks"
    encrypt        = true
  }
}
