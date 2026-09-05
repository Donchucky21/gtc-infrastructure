variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster."
}

variable "oidc_provider_arn" {
  type        = string
  description = "EKS OIDC provider ARN used for IRSA."
}

variable "namespace" {
  type        = string
  description = "Namespace where External Secrets Operator is installed."
  default     = "external-secrets"
}

variable "service_account_name" {
  type        = string
  description = "Service account name used by External Secrets Operator."
  default     = "external-secrets"
}

variable "chart_version" {
  type        = string
  description = "External Secrets Operator Helm chart version."
  default     = "2.7.0"
}

variable "ssm_parameter_arns" {
  type        = list(string)
  description = "SSM Parameter Store parameter ARNs the operator can read. Use narrower ARNs when possible."
  default     = ["*"]
}

variable "kms_key_arns" {
  type        = list(string)
  description = "KMS key ARNs the operator can decrypt for SecureString parameters."
  default     = ["*"]
}
