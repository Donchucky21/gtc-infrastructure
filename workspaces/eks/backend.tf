
# # make s3 bucket for terraform state
terraform {
  backend "s3" {
    bucket       = "chuckys-remote-state"
    key          = "eks/prod/terraform.tfstate"
    region       = "eu-west-2"
    use_lockfile = true
    # dynamodb_table = "gtc-terraform-state-locks"
    encrypt = true
  }
}

