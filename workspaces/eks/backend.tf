
# # make s3 bucket for terraform state
terraform {
  backend "s3" {
    bucket         = "ap-terraform-state"
    key            = "new-dev"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
  }
}

