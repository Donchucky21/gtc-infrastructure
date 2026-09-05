#Requires -Version 7.4
param(
  [string]$Namespace = "monitoring",
  [string]$StorageClassName = "gp3",

  [string]$LokiStorageSize       = "200Gi",
  [string]$GrafanaStorageSize    = "50Gi",
  [string]$PrometheusStorageSize = "50Gi",
  [string]$TempoStorageSize      = "50Gi",

  [string]$LokiRelease    = "loki",
  [string]$GrafanaRelease = "grafana",
  [string]$PromRelease    = "kps",
  [string]$TempoRelease   = "tempo",
  [string]$OtelRelease    = "otel",

  # Your chosen Grafana admin password (retained across redeploys)
  [Parameter(Mandatory = $true)]
  [string]$GrafanaAdminPassword
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true
Set-StrictMode -Version Latest

function Assert-Cmd($name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    throw "Required command not found in PATH: $name"
  }
}

Assert-Cmd kubectl
Assert-Cmd helm

Write-Host "==> Namespace: $Namespace"
Write-Host "==> StorageClass: $StorageClassName"
Write-Host "==> Grafana password: (using provided value)"
Write-Host "==> APM: Grafana Tempo + OpenTelemetry Collector will be installed"

# Helm repos
Write-Host "==> Adding/Updating Helm repos..."
helm repo add grafana https://grafana.github.io/helm-charts | Out-Null
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts | Out-Null
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts | Out-Null
helm repo update | Out-Null

# Preserve existing releases and persistent volumes on repeat applies.
$existingNamespace = kubectl get namespace $Namespace --ignore-not-found -o name
if ([string]::IsNullOrWhiteSpace($existingNamespace)) {
  kubectl create namespace $Namespace | Out-Null
}

# Temp directory for values
$tempDir = Join-Path $env:TEMP ("monitoring-redeploy-" + [guid]::NewGuid().ToString("n"))
New-Item -ItemType Directory -Path $tempDir | Out-Null

$lokiValues    = Join-Path $tempDir "loki-values.yaml"
$grafanaValues = Join-Path $tempDir "grafana-values.yaml"
$promValues    = Join-Path $tempDir "prom-values.yaml"
$tempoValues   = Join-Path $tempDir "tempo-values.yaml"
$otelValues    = Join-Path $tempDir "otel-values.yaml"

# ---- Loki + Promtail (grafana/loki-stack) ----
@"
loki:
  enabled: true
  persistence:
    enabled: true
    size: $LokiStorageSize
    storageClassName: $StorageClassName
  config:
    auth_enabled: false

promtail:
  enabled: true

# Grafana is installed separately below.
grafana:
  enabled: false
"@ | Set-Content -Path $lokiValues -Encoding UTF8

# ---- Prometheus (kube-prometheus-stack) ----
@"
grafana:
  enabled: false

alertmanager:
  enabled: false

prometheus:
  prometheusSpec:
    retention: 7d
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: $StorageClassName
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: $PrometheusStorageSize

kubeStateMetrics:
  enabled: true

nodeExporter:
  enabled: true
"@ | Set-Content -Path $promValues -Encoding UTF8

# ---- Tempo (single binary) ----
# Receives traces from the OpenTelemetry Collector using OTLP gRPC on 4317.
# Grafana queries Tempo using HTTP on 3100.
@"
tempo:
  reportingEnabled: false
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318

persistence:
  enabled: true
  storageClassName: $StorageClassName
  size: $TempoStorageSize

service:
  type: ClusterIP
"@ | Set-Content -Path $tempoValues -Encoding UTF8

# ---- OpenTelemetry Collector ----
# Apps send telemetry to this collector.
# Java agent HTTP endpoint: http://otel-opentelemetry-collector.monitoring.svc:4318
# Java agent gRPC endpoint: http://otel-opentelemetry-collector.monitoring.svc:4317
@"
mode: deployment

image:
  repository: otel/opentelemetry-collector-contrib

command:
  name: otelcol-contrib

presets:
  logsCollection:
    enabled: false
  hostMetrics:
    enabled: false
  kubernetesAttributes:
    enabled: true

service:
  type: ClusterIP

ports:
  otlp:
    enabled: true
    containerPort: 4317
    servicePort: 4317
    protocol: TCP
  otlp-http:
    enabled: true
    containerPort: 4318
    servicePort: 4318
    protocol: TCP
  metrics:
    enabled: true
    containerPort: 8888
    servicePort: 8888
    protocol: TCP

config:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318

  processors:
    memory_limiter:
      check_interval: 1s
      limit_percentage: 75
      spike_limit_percentage: 15
    batch:
      timeout: 5s
      send_batch_size: 1024
    k8sattributes:
      auth_type: serviceAccount
      passthrough: false
      extract:
        metadata:
          - k8s.namespace.name
          - k8s.pod.name
          - k8s.deployment.name
          - k8s.node.name

  exporters:
    otlp/tempo:
      endpoint: $TempoRelease.$Namespace.svc.cluster.local:4317
      tls:
        insecure: true
    debug:
      verbosity: basic

  service:
    telemetry:
      logs:
        level: info
      metrics:
        address: 0.0.0.0:8888
    pipelines:
      traces:
        receivers: [otlp]
        processors: [memory_limiter, k8sattributes, batch]
        exporters: [otlp/tempo]
"@ | Set-Content -Path $otelValues -Encoding UTF8

# ---- Grafana (grafana/grafana) ----
# Setting adminPassword ensures the secret generated by the chart uses YOUR password.
# Includes Prometheus, Loki and Tempo datasources.
@"
adminUser: admin
adminPassword: "$GrafanaAdminPassword"

persistence:
  type: pvc
  enabled: true
  storageClassName: $StorageClassName
  accessModes:
    - ReadWriteOnce
  size: $GrafanaStorageSize

datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
      - name: Prometheus
        uid: prometheus
        type: prometheus
        access: proxy
        url: http://$PromRelease-kube-prometheus-stack-prometheus.$Namespace.svc:9090
        isDefault: true
      - name: Loki
        uid: loki
        type: loki
        access: proxy
        url: http://$LokiRelease.$Namespace.svc:3100
      - name: Tempo
        uid: tempo
        type: tempo
        access: proxy
        url: http://$TempoRelease.$Namespace.svc:3200
        jsonData:
          httpMethod: GET
          tracesToLogsV2:
            datasourceUid: loki
            spanStartTimeShift: '-5m'
            spanEndTimeShift: '5m'
            filterByTraceID: true
            filterBySpanID: false
          serviceMap:
            datasourceUid: prometheus
"@ | Set-Content -Path $grafanaValues -Encoding UTF8

Write-Host "==> Values files created in: $tempDir"

# Install Loki+Promtail
Write-Host "==> Installing Loki + Promtail..."
helm upgrade --install $LokiRelease grafana/loki-stack `
  -n $Namespace `
  -f $lokiValues `
  --atomic --wait --timeout 10m

# Install Prometheus stack
Write-Host "==> Installing Prometheus (kube-prometheus-stack)..."
helm upgrade --install $PromRelease prometheus-community/kube-prometheus-stack `
  -n $Namespace `
  -f $promValues `
  --atomic --wait --timeout 10m

# Install Tempo
Write-Host "==> Installing Tempo..."
helm upgrade --install $TempoRelease grafana/tempo `
  -n $Namespace `
  -f $tempoValues `
  --atomic --wait --timeout 10m

# Install OpenTelemetry Collector
Write-Host "==> Installing OpenTelemetry Collector..."
helm upgrade --install $OtelRelease open-telemetry/opentelemetry-collector `
  -n $Namespace `
  -f $otelValues `
  --atomic --wait --timeout 10m

# Install Grafana
Write-Host "==> Installing Grafana..."
helm upgrade --install $GrafanaRelease grafana/grafana `
  -n $Namespace `
  -f $grafanaValues `
  --atomic --wait --timeout 10m

Write-Host ""
Write-Host "==> Pods:"
kubectl -n $Namespace get pods -o wide

Write-Host ""
Write-Host "==> Services:"
kubectl -n $Namespace get svc

Write-Host ""
Write-Host "==> PVCs (confirm storage class + sizes):"
kubectl -n $Namespace get pvc

Write-Host ""
Write-Host "==> Access Grafana:"
Write-Host "  kubectl -n $Namespace port-forward svc/$GrafanaRelease 3000:80"
Write-Host "  then open http://localhost:3000"
Write-Host ""
Write-Host "==> Grafana login:"
Write-Host "  user: admin"
Write-Host "  Retrieve the password from the sensitive Terraform output grafana_admin_password."
Write-Host ""
Write-Host "==> Java auto-instrumentation example for your application Deployment:"
Write-Host "  Add the OpenTelemetry Java agent to the container image or mount it with an initContainer."
Write-Host "  Then set these environment variables:"
Write-Host ""
Write-Host "  JAVA_TOOL_OPTIONS=-javaagent:/otel/opentelemetry-javaagent.jar"
Write-Host "  OTEL_SERVICE_NAME=<your-service-name>"
Write-Host "  OTEL_EXPORTER_OTLP_ENDPOINT=http://$OtelRelease-opentelemetry-collector.$Namespace.svc:4318"
Write-Host "  OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf"
Write-Host "  OTEL_TRACES_EXPORTER=otlp"
Write-Host "  OTEL_METRICS_EXPORTER=none"
Write-Host "  OTEL_LOGS_EXPORTER=none"
Write-Host ""
Write-Host "==> Flow: Java app -> OpenTelemetry Collector -> Tempo -> Grafana"