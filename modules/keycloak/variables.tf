variable "namespace" {
  type    = string
  default = "keycloak"
}

variable "release_name" {
  type    = string
  default = "keycloak"
}

variable "image" {
  type        = string
  default     = "quay.io/keycloak/keycloak:26.3.3"
  description = "Official Keycloak container image."
}

variable "hostname" {
  type        = string
  description = "DNS hostname for Keycloak."
}

variable "admin_user" {
  type    = string
  default = "admin"
}

variable "admin_secret_name" {
  type        = string
  default     = "keycloak-admin-creds"
  description = "Existing Kubernetes secret containing the Keycloak admin password."
}

variable "admin_password_secret_key" {
  type    = string
  default = "admin-password"
}

variable "database_host" {
  type        = string
  description = "External PostgreSQL host."
}

variable "database_port" {
  type    = number
  default = 5432
}

variable "database_name" {
  type    = string
  default = "keycloak"
}

variable "database_schema" {
  type    = string
  default = "public"
}

variable "database_secret_name" {
  type        = string
  default     = "keycloak-db-creds"
  description = "Existing Kubernetes secret containing external PostgreSQL username and password."
}

variable "database_username_secret_key" {
  type    = string
  default = "username"
}

variable "database_password_secret_key" {
  type    = string
  default = "password"
}

variable "replica_count" {
  type    = number
  default = 1
}

variable "resources" {
  type = object({
    requests = optional(map(string), {})
    limits   = optional(map(string), {})
  })
  default = {
    requests = {
      cpu    = "250m"
      memory = "512Mi"
    }
    limits = {
      memory = "1Gi"
    }
  }
}

variable "ingress_class_name" {
  type    = string
  default = "alb"
}

variable "ingress_scheme" {
  type    = string
  default = "internet-facing"
}

variable "ingress_group_name" {
  type    = string
  default = "mygreenpole-com"
}

variable "ingress_group_order" {
  type    = string
  default = "20"
}

variable "ingress_load_balancer_name" {
  type    = string
  default = "mygreenpole-com-alb"
}

variable "ingress_certificate_arn" {
  type    = string
  default = "arn:aws:acm:eu-west-2:825765408263:certificate/9a70b7b2-5213-4ac9-a0f5-9fa6ae868974"
}

variable "ingress_listen_ports" {
  type    = string
  default = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
}

variable "ingress_backend_protocol" {
  type    = string
  default = "HTTP"
}

variable "ingress_success_codes" {
  type    = string
  default = "200-399,404"
}
