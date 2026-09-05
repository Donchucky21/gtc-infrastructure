locals {
  hostname = coalesce(var.hostname, "keycloak.${var.zone}")
}

module "keycloak" {
  source = "../../modules/keycloak"

  namespace    = var.namespace
  release_name = var.release_name
  image        = var.image
  hostname     = local.hostname

  admin_user                = var.admin_user
  admin_secret_name         = var.admin_secret_name
  admin_password_secret_key = var.admin_password_secret_key

  database_host                = var.database_host
  database_port                = var.database_port
  database_name                = var.database_name
  database_schema              = var.database_schema
  database_secret_name         = var.database_secret_name
  database_username_secret_key = var.database_username_secret_key
  database_password_secret_key = var.database_password_secret_key

  ingress_group_name         = var.ingress_group_name
  ingress_group_order        = var.ingress_group_order
  ingress_load_balancer_name = var.ingress_load_balancer_name
  ingress_certificate_arn    = var.ingress_certificate_arn
  ingress_listen_ports       = var.ingress_listen_ports
  ingress_backend_protocol   = var.ingress_backend_protocol
  ingress_success_codes      = var.ingress_success_codes

  providers = {
    kubernetes = kubernetes
  }
}
