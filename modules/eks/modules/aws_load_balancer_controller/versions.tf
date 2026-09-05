terraform {
  required_version = "~> 1.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.10"
    }
    helm = {
      version = "~> 2.9.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.13.0"
    }
  }
}

