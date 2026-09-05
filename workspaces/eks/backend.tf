
# # make s3 bucket for terraform state
terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket-victory"
    key            = "new-dev"
    region         = "eu-west-2"
    dynamodb_table = "terraform-state-locks-victory"
  }
}

