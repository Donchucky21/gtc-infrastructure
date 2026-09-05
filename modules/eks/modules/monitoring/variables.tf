variable "grafana_admin_password" {
  type    = string
  default = null
}

variable "monitoring_script_path" {
  type        = string
  description = "Path to the PowerShell script used to redeploy monitoring."
  default     = "monitoring-redeploy-with-apm.ps1"
}

variable "namespace" {
  type    = string
  default = "monitoring"
}

variable "storage_class_name" {
  type    = string
  default = "gp3"
}

variable "loki_storage_size" {
  type    = string
  default = "200Gi"
}

variable "grafana_storage_size" {
  type    = string
  default = "50Gi"
}

variable "prometheus_storage_size" {
  type    = string
  default = "50Gi"
}

variable "tempo_storage_size" {
  type    = string
  default = "50Gi"
}

variable "loki_release" {
  type    = string
  default = "loki"
}

variable "grafana_release" {
  type    = string
  default = "grafana"
}

variable "prometheus_release" {
  type    = string
  default = "kps"
}

variable "tempo_release" {
  type    = string
  default = "tempo"
}

variable "otel_release" {
  type    = string
  default = "otel"
}
