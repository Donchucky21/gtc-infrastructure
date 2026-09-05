variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster."
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version for the EKS control plane."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the EKS cluster is deployed."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for EKS managed node groups."
}

variable "control_plane_subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for EKS control plane ENIs. Defaults to subnet_ids."
  default     = null
}

variable "admin_principal_arns" {
  type        = list(string)
  description = "IAM principal ARNs granted cluster-admin access through EKS access entries."
  default     = []
}

variable "node_instance_types" {
  type        = list(string)
  description = "Instance types for the default EKS managed node group."
  default     = ["c6a.xlarge"]
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

variable "tags" {
  type    = map(string)
  default = {}
}
