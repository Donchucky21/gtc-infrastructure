terraform {
  backend "s3" {
    bucket       = "chuckys-remote-state"
    key          = "argocd/prod/terraform.tfstate"
    region       = "eu-west-2"
    use_lockfile = true
    encrypt      = true
  }
}
