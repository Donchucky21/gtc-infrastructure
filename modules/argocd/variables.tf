variable "namespace" {
  type    = string
  default = "argocd"
}

variable "release_name" {
  type    = string
  default = "argocd"
}

variable "chart_version" {
  type        = string
  default     = "7.8.2"
  description = "Argo CD Helm chart version."
}

variable "server_service_type" {
  type    = string
  default = "ClusterIP"
}

variable "hostname" {
  type        = string
  description = "DNS hostname for the Argo CD server."
}

variable "github_account" {
  type        = string
  description = "GitHub account or username used with the PAT."

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
  description = "Git revision watched by the ApplicationSet."
  default     = "main"
}

variable "applicationset_name" {
  type        = string
  description = "ApplicationSet name. Defaults to <argocd_deployment_name>-services."
  default     = null
}

variable "applicationset_path" {
  type        = string
  description = "Directory glob inside the Git repository used by the ApplicationSet generator. Defaults to <gitops_root_path>/services/*/*."
  default     = null
}

variable "application_destination_namespace" {
  type        = string
  description = "Destination namespace for generated Applications."
  default     = "global"
}

variable "argocd_deployment_name" {
  type        = string
  description = "Prefix used for Argo CD bootstrap resource names."
  default     = "argocd"
}

variable "gitops_root_path" {
  type        = string
  description = "Root path inside the GitOps repository for this environment."
  default     = "prod"
}

variable "enable_bootstrap_application" {
  type        = bool
  description = "Whether to create the bootstrap Argo CD Application."
  default     = true
}

variable "bootstrap_application_name" {
  type        = string
  description = "Name of the bootstrap Argo CD Application."
  default     = "bootstrap"
}

variable "bootstrap_path" {
  type        = string
  description = "Path inside the Git repository for the bootstrap Application. Defaults to <gitops_root_path>/bootstrap."
  default     = null
}

variable "bootstrap_destination_namespace" {
  type        = string
  description = "Destination namespace for the bootstrap Application."
  default     = "global"
}

variable "enable_applicationset" {
  type        = bool
  description = "Whether to create the services ApplicationSet."
  default     = true
}

variable "ingress_class_name" {
  type    = string
  default = "alb"
}

variable "ingress_scheme" {
  type    = string
  default = "internet-facing"
}

variable "ingress_listen_ports" {
  type        = string
  description = "AWS Load Balancer Controller listen-ports annotation value for the Argo CD ingress."
  default     = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
}

variable "ingress_certificate_arn" {
  type        = string
  description = "ACM certificate ARN used by the AWS Load Balancer Controller for the Argo CD ingress."
  default     = null
}
