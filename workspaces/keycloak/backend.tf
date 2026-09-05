terraform {
  backend "s3" {
    bucket         = "ap-terraform-state"
    key            = "keycloak"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
  }
}
