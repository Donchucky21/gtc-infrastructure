output "namespace" {
  value = var.namespace
}

output "release_name" {
  value = helm_release.argocd.name
}

output "server_port_forward_command" {
  value = "kubectl -n ${var.namespace} port-forward svc/${var.release_name}-server 8080:443"
}

output "hostname" {
  value = var.hostname
}

output "applicationset_name" {
  value = local.applicationset_name
}

output "bootstrap_application_name" {
  value = var.bootstrap_application_name
}

output "bootstrap_path" {
  value = local.bootstrap_path
}

output "applicationset_path" {
  value = local.applicationset_path
}
