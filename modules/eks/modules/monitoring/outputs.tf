output "grafana_admin_password" {
  value     = local.grafana_admin_password
  sensitive = true
}

output "namespace" {
  value = local.namespace
}

output "grafana_port_forward_command" {
  value = "kubectl -n ${local.namespace} port-forward svc/${var.grafana_release} 3000:80"
}
