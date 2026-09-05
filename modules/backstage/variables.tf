variable "namespace" {
  type    = string
  default = "backstage"
}

variable "release_name" {
  type    = string
  default = "backstage"
}

variable "chart_version" {
  type        = string
  default     = null
  description = "Optional backstage Helm chart version. Leave null to install the latest chart from the repository."
}

variable "hostname" {
  type        = string
  description = "DNS hostname for Backstage."
}

variable "github_token" {
  type        = string
  description = "GitHub token used by Backstage integrations and catalog imports."
  sensitive   = true
}

variable "catalog_locations" {
  type = list(object({
    type   = string
    target = string
  }))
  description = "Backstage catalog locations to import, for example existing repository catalog-info.yaml URLs."
  default     = []
}

variable "app_title" {
  type    = string
  default = "AP Developer Portal"
}

variable "ingress_class_name" {
  type    = string
  default = "alb"
}

variable "ingress_scheme" {
  type    = string
  default = "internet-facing"
}
