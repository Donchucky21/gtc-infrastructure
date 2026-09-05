variable "region" {
  type    = string
  default = "eu-west-2"
}

variable "eks_cluster_name" {
  type        = string
  description = "Name of the existing EKS cluster."
}

variable "namespace" {
  type    = string
  default = "keycloak"
}

variable "release_name" {
  type    = string
  default = "keycloak"
}

variable "image" {
  type    = string
  default = "quay.io/keycloak/keycloak:26.3.3"
}

variable "zone" {
  type    = string
  default = "mygreenpole.com"
}

variable "hostname" {
  type        = string
  default     = null
  description = "Keycloak hostname. Defaults to keycloak.<zone>."
}

variable "admin_user" {
  type    = string
  default = "admin"
}

variable "admin_secret_name" {
  type    = string
  default = "keycloak-admin-creds"
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
  type    = string
  default = "keycloak-db-creds"
}

variable "database_username_secret_key" {
  type    = string
  default = "username"
}

variable "database_password_secret_key" {
  type    = string
  default = "password"
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
