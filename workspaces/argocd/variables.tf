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

variable "argocd_hostname" {
  type        = string
  description = "DNS hostname for Argo CD. Defaults to argocd.<zone>."
  default     = null
}

variable "github_account" {
  type        = string
  description = "GitHub account or username used by Argo CD with the PAT."

  validation {
    condition     = !can(regex("^https?://", var.github_account)) && !can(regex("/", var.github_account))
    error_message = "github_account must be a GitHub username/account name only, not a URL."
  }
}

variable "github_pat_token" {
  type        = string
  description = "GitHub personal access token used by Argo CD to read the repository."
  sensitive   = true
}

variable "github_repository_url" {
  type        = string
  description = "Git repository URL watched by Argo CD."

  validation {
    condition     = !can(regex("/tree/", var.github_repository_url)) && !can(regex("/blob/", var.github_repository_url))
    error_message = "github_repository_url must be the repository clone URL, not a GitHub browser URL with /tree/ or /blob/. Put subdirectories in gitops_root_path."
  }
}

variable "github_revision" {
  type        = string
  description = "Git revision watched by Argo CD."
  default     = "main"
}

variable "gitops_root_path" {
  type        = string
  description = "Root path inside the GitOps repository for this environment."
  default     = "prod"
}

variable "argocd_deployment_name" {
  type        = string
  description = "Prefix used for Argo CD bootstrap resource names."
  default     = "argocd"
}

variable "application_destination_namespace" {
  type        = string
  description = "Destination namespace for generated Applications."
  default     = "global"
}

variable "bootstrap_destination_namespace" {
  type        = string
  description = "Destination namespace for the bootstrap Application."
  default     = "global"
}

variable "ingress_certificate_arn" {
  type        = string
  description = "ACM certificate ARN used by the AWS Load Balancer Controller for the Argo CD ingress."
  default     = "arn:aws:acm:eu-west-2:825765408263:certificate/9a70b7b2-5213-4ac9-a0f5-9fa6ae868974"
}
