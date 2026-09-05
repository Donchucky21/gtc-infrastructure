locals {
  labels = {
    "app.kubernetes.io/name"       = "keycloak"
    "app.kubernetes.io/instance"   = var.release_name
    "app.kubernetes.io/managed-by" = "terraform"
  }

  ingress_annotations = {
    "alb.ingress.kubernetes.io/backend-protocol"   = var.ingress_backend_protocol
    "alb.ingress.kubernetes.io/certificate-arn"    = var.ingress_certificate_arn
    "alb.ingress.kubernetes.io/group.name"         = var.ingress_group_name
    "alb.ingress.kubernetes.io/group.order"        = var.ingress_group_order
    "alb.ingress.kubernetes.io/listen-ports"       = var.ingress_listen_ports
    "alb.ingress.kubernetes.io/load-balancer-name" = var.ingress_load_balancer_name
    "alb.ingress.kubernetes.io/scheme"             = var.ingress_scheme
    "alb.ingress.kubernetes.io/success-codes"      = var.ingress_success_codes
    "alb.ingress.kubernetes.io/target-type"        = "ip"
    "external-dns.alpha.kubernetes.io/hostname"    = var.hostname
  }
}

resource "kubernetes_deployment_v1" "keycloak" {
  metadata {
    name      = var.release_name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    replicas = var.replica_count

    selector {
      match_labels = local.labels
    }

    template {
      metadata {
        labels = local.labels
      }

      spec {
        container {
          name              = "keycloak"
          image             = var.image
          image_pull_policy = "IfNotPresent"
          args              = ["start"]

          port {
            name           = "http"
            container_port = 8080
          }

          port {
            name           = "management"
            container_port = 9000
          }

          env {
            name  = "KC_DB"
            value = "postgres"
          }

          env {
            name  = "KC_DB_URL"
            value = "jdbc:postgresql://${var.database_host}:${var.database_port}/${var.database_name}?currentSchema=${var.database_schema}"
          }

          env {
            name = "KC_DB_USERNAME"
            value_from {
              secret_key_ref {
                name = var.database_secret_name
                key  = var.database_username_secret_key
              }
            }
          }

          env {
            name = "KC_DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = var.database_secret_name
                key  = var.database_password_secret_key
              }
            }
          }

          env {
            name  = "KC_BOOTSTRAP_ADMIN_USERNAME"
            value = var.admin_user
          }

          env {
            name = "KC_BOOTSTRAP_ADMIN_PASSWORD"
            value_from {
              secret_key_ref {
                name = var.admin_secret_name
                key  = var.admin_password_secret_key
              }
            }
          }

          env {
            name  = "KC_HTTP_ENABLED"
            value = "true"
          }

          env {
            name  = "KC_PROXY_HEADERS"
            value = "xforwarded"
          }

          env {
            name  = "KC_HOSTNAME"
            value = "https://${var.hostname}"
          }

          env {
            name  = "KC_HOSTNAME_STRICT"
            value = "true"
          }

          env {
            name  = "KC_HEALTH_ENABLED"
            value = "true"
          }

          readiness_probe {
            http_get {
              path = "/health/ready"
              port = "management"
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 12
          }

          liveness_probe {
            http_get {
              path = "/health/live"
              port = "management"
            }
            initial_delay_seconds = 60
            period_seconds        = 30
            timeout_seconds       = 5
            failure_threshold     = 6
          }

          resources {
            requests = var.resources.requests
            limits   = var.resources.limits
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "keycloak" {
  metadata {
    name      = var.release_name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    type     = "ClusterIP"
    selector = local.labels

    port {
      name        = "http"
      port        = 8080
      target_port = "http"
    }
  }
}

resource "kubernetes_ingress_v1" "keycloak" {
  metadata {
    name        = var.release_name
    namespace   = var.namespace
    labels      = local.labels
    annotations = local.ingress_annotations
  }

  spec {
    ingress_class_name = var.ingress_class_name

    rule {
      host = var.hostname

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.keycloak.metadata[0].name

              port {
                name = "http"
              }
            }
          }
        }
      }
    }
  }
}
