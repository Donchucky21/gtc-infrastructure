locals {
  namespace              = var.namespace
  monitoring_script_path = abspath("${path.module}/${var.monitoring_script_path}")
  grafana_admin_password = var.grafana_admin_password != null ? var.grafana_admin_password : random_password.grafana[0].result
}

resource "random_password" "grafana" {
  count   = var.grafana_admin_password == null ? 1 : 0
  length  = 40
  special = false
}

resource "null_resource" "monitoring_redeploy" {
  triggers = {
    script_sha              = filesha256(local.monitoring_script_path)
    namespace               = local.namespace
    storage_class_name      = var.storage_class_name
    loki_storage_size       = var.loki_storage_size
    grafana_storage_size    = var.grafana_storage_size
    prometheus_storage_size = var.prometheus_storage_size
    tempo_storage_size      = var.tempo_storage_size
    loki_release            = var.loki_release
    grafana_release         = var.grafana_release
    prometheus_release      = var.prometheus_release
    tempo_release           = var.tempo_release
    otel_release            = var.otel_release
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
    command     = <<-EOT
      & "${local.monitoring_script_path}" `
        -Namespace "${local.namespace}" `
        -StorageClassName "${var.storage_class_name}" `
        -LokiStorageSize "${var.loki_storage_size}" `
        -GrafanaStorageSize "${var.grafana_storage_size}" `
        -PrometheusStorageSize "${var.prometheus_storage_size}" `
        -TempoStorageSize "${var.tempo_storage_size}" `
        -LokiRelease "${var.loki_release}" `
        -GrafanaRelease "${var.grafana_release}" `
        -PromRelease "${var.prometheus_release}" `
        -TempoRelease "${var.tempo_release}" `
        -OtelRelease "${var.otel_release}" `
        -GrafanaAdminPassword $env:GRAFANA_ADMIN_PASSWORD
    EOT

    environment = {
      GRAFANA_ADMIN_PASSWORD = local.grafana_admin_password
    }
  }
}
