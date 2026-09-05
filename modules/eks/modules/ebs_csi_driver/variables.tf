variable "oidc_provider_arn" {
  type = string
}
variable "cluster_name" {
  type = string
}

variable "region" {
  type        = string
  description = "AWS region where the EKS cluster is deployed."
}
