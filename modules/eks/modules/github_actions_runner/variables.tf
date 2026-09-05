variable "github_config_url" {
  type        = string
  description = "GitHub repository, organization, or enterprise URL that owns the runner scale set."
}

variable "github_token" {
  type        = string
  description = "GitHub PAT used by ARC to register runner scale set runners."
  sensitive   = true
  default     = null
}

variable "github_config_secret_name" {
  type        = string
  description = "Name of an existing Kubernetes secret in the runner namespace containing ARC GitHub auth keys."
  default     = null
}

variable "controller_namespace" {
  type        = string
  description = "Namespace for the ARC controller."
  default     = "arc-systems"
}

variable "runner_namespace" {
  type        = string
  description = "Namespace where runner scale set resources and runner pods are created."
  default     = "arc-runners"
}

variable "controller_release_name" {
  type        = string
  description = "Helm release name for the ARC controller."
  default     = "arc"
}

variable "runner_scale_set_name" {
  type        = string
  description = "Runner scale set name. Use this value in workflow runs-on."
  default     = "ap-infra-eks-runner"
}

variable "chart_version" {
  type        = string
  description = "ARC Helm chart version. Null installs the latest available chart."
  default     = null
}

variable "min_runners" {
  type        = number
  description = "Minimum number of idle runners."
  default     = 0
}

variable "max_runners" {
  type        = number
  description = "Maximum number of runner pods ARC can create."
  default     = 3
}
