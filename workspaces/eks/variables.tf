variable "environment" {
  type    = string
  default = "dev"
}
variable "region" {
  type    = string
  default = "eu-west-2"
}
variable "eks_cluster_version" {
  type    = string
  default = "1.36"
}
variable "eks_admin_principal_arns" {
  type        = list(string)
  description = "IAM principal ARNs granted cluster-admin access through EKS access entries."
  default     = []

  validation {
    condition     = alltrue([for arn in var.eks_admin_principal_arns : can(regex("^arn:aws:iam::[0-9]{12}:(role|user)/.+$", arn))])
    error_message = "Each EKS admin principal ARN must be an IAM role or user ARN."
  }
}
variable "max_nodes" {
  type    = number
  default = 5
}
variable "min_nodes" {
  type    = number
  default = 1
}

variable "desired_size" {
  type    = number
  default = 2
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block used by the EKS VPC."
}

variable "zone" {
  type        = string
  description = "Public Route53 zone name used by ingress and external-dns."
}

variable "external_secrets_ssm_parameter_arns" {
  type        = list(string)
  description = "SSM Parameter Store parameter ARNs External Secrets Operator can read."
  default     = ["*"]
}

variable "external_secrets_kms_key_arns" {
  type        = list(string)
  description = "KMS key ARNs External Secrets Operator can decrypt for SecureString parameters."
  default     = ["*"]
}

variable "github_runner_config_url" {
  type        = string
  description = "GitHub repository, organization, or enterprise URL that owns the self-hosted runner scale set."
  default     = "https://github.com/africa-prudential"
}

variable "github_runner_token" {
  type        = string
  description = "GitHub token used by ARC to register self-hosted runners."
  sensitive   = true
  default     = null
}

variable "github_runner_scale_set_name" {
  type        = string
  description = "Runner scale set label to use in workflow runs-on."
  default     = "ap-infra-eks-runner"
}

variable "github_runner_min_runners" {
  type        = number
  description = "Minimum number of idle self-hosted runners."
  default     = 0
}

variable "github_runner_max_runners" {
  type        = number
  description = "Maximum number of self-hosted runner pods ARC can create."
  default     = 3
}
