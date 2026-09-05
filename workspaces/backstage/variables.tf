variable "region" {
  type    = string
  default = "eu-west-2"
}

variable "eks_cluster_name" {
  type        = string
  description = "Name of the existing EKS cluster."
}

variable "zone" {
  type        = string
  description = "Public Route53 zone name used by ingress and external-dns."
}

variable "backstage_hostname" {
  type        = string
  description = "DNS hostname for Backstage. Defaults to backstage.<zone>."
  default     = null
}

variable "github_pat_token" {
  type        = string
  description = "GitHub personal access token used by Backstage integrations."
  sensitive   = true
}

variable "backstage_catalog_locations" {
  type = list(object({
    type   = string
    target = string
  }))
  description = "Existing repository catalog locations for Backstage to import."
  default     = []
}
