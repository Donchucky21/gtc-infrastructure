locals {
  gitops_root_path = trim(var.gitops_root_path, "/")

  bootstrap_path = coalesce(
    var.bootstrap_path,
    local.gitops_root_path == "" || local.gitops_root_path == "." ? "bootstrap" : "${local.gitops_root_path}/bootstrap"
  )

  applicationset_path = coalesce(
    var.applicationset_path,
    local.gitops_root_path == "" || local.gitops_root_path == "." ? "services/*/*" : "${local.gitops_root_path}/services/*/*"
  )

  applicationset_name = coalesce(var.applicationset_name, "${var.argocd_deployment_name}-services")

  bootstrap_application = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = var.bootstrap_application_name
      namespace = var.namespace
      finalizers = [
        "resources-finalizer.argocd.argoproj.io"
      ]
    }
    spec = {
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.bootstrap_destination_namespace
      }
      project = "default"
      source = {
        path           = local.bootstrap_path
        repoURL        = var.github_repository_url
        targetRevision = var.github_revision
        directory = {
          recurse = true
          exclude = "catalog-info.yaml"
        }
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
        retry = {
          limit = 5
          backoff = {
            duration    = "5s"
            factor      = 2
            maxDuration = "3m0s"
          }
        }
      }
    }
  }

  applicationset = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "ApplicationSet"
    metadata = {
      name      = local.applicationset_name
      namespace = var.namespace
    }
    spec = {
      goTemplate        = true
      goTemplateOptions = ["missingkey=error"]
      generators = [
        {
          git = {
            repoURL  = var.github_repository_url
            revision = var.github_revision
            directories = [
              {
                path = local.applicationset_path
              }
            ]
          }
        }
      ]
      template = {
        metadata = {
          name = "{{ normalize .path.path }}"
        }
        spec = {
          project = "default"
          source = {
            repoURL        = var.github_repository_url
            targetRevision = var.github_revision
            path           = "{{.path.path}}"
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = var.application_destination_namespace
          }
          syncPolicy = {
            automated = {
              prune    = true
              selfHeal = true
            }
            syncOptions = [
              "CreateNamespace=true"
            ]
            retry = {
              limit = 5
              backoff = {
                duration    = "5s"
                factor      = 2
                maxDuration = "3m0s"
              }
            }
          }
        }
      }
    }
  }

  extra_objects = concat(
    var.enable_bootstrap_application ? [local.bootstrap_application] : [],
    var.enable_applicationset ? [local.applicationset] : []
  )

  extra_objects_yaml        = join("\n---\n", [for object in local.extra_objects : yamlencode(object)])
  extra_objects_yaml_base64 = base64encode(local.extra_objects_yaml)

  ingress_annotations = merge(
    {
      "external-dns.alpha.kubernetes.io/hostname"    = var.hostname
      "alb.ingress.kubernetes.io/scheme"             = var.ingress_scheme
      "alb.ingress.kubernetes.io/listen-ports"       = var.ingress_listen_ports
      "alb.ingress.kubernetes.io/backend-protocol"   = "HTTP"
      "alb.ingress.kubernetes.io/target-type"        = "ip"
      "alb.ingress.kubernetes.io/load-balancer-name" = "central-alb"
      "alb.ingress.kubernetes.io/group.name"         = "central"
    },
    var.ingress_certificate_arn != null ? {
      "alb.ingress.kubernetes.io/certificate-arn" = var.ingress_certificate_arn
    } : {}
  )
}

resource "helm_release" "argocd" {
  name             = var.release_name
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  values = [
    yamlencode({
      global = {
        domain = var.hostname
      }
      server = {
        service = {
          type = var.server_service_type
        }
        ingress = {
          enabled          = true
          ingressClassName = var.ingress_class_name
          hostname         = var.hostname
          path             = "/"
          pathType         = "Prefix"
          annotations      = local.ingress_annotations
        }
      }
      configs = {
        params = {
          "server.insecure" = true
        }
        repositories = {
          github = {
            name     = "github"
            type     = "git"
            url      = var.github_repository_url
            username = var.github_account
          }
        }
      }
    })
  ]

  set_sensitive {
    name  = "configs.repositories.github.password"
    value = var.github_pat_token
  }
}

resource "null_resource" "argocd_extra_objects" {
  count = length(local.extra_objects) > 0 ? 1 : 0

  triggers = {
    objects_yaml_sha = sha256(local.extra_objects_yaml)
    namespace        = var.namespace
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
    command     = <<-EOT
      kubectl wait --for condition=Established --timeout=120s crd/applications.argoproj.io crd/applicationsets.argoproj.io
      if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
      }

      $manifestPath = Join-Path $env:TEMP "argocd-extra-objects.yaml"
      $manifest = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("${local.extra_objects_yaml_base64}"))
      Set-Content -Path $manifestPath -Value $manifest -Encoding UTF8

      kubectl apply -n "${var.namespace}" -f $manifestPath
      if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
      }
    EOT
  }

  depends_on = [helm_release.argocd]
}
