output "release_name" {
  value = kubernetes_deployment_v1.keycloak.metadata[0].name
}

output "namespace" {
  value = var.namespace
}

output "hostname" {
  value = var.hostname
}

output "issuer_url" {
  value = "https://${var.hostname}/realms/<realm-name>"
}
