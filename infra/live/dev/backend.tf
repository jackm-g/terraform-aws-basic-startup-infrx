terraform {
  backend "s3" {
    bucket         = "jg3-app-tfstate" # Change to your own bucket name
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "jg3-app-tf-locks" # Change to your own table name
    encrypt        = true
  }
}
