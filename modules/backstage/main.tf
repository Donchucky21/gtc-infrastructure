locals {
  backend_secret_name      = "${var.release_name}-backend-secret"
  app_config_name          = "${var.release_name}-app-config"
  backstage_backend_secret = random_password.backend_secret.result

  catalog_locations = concat(
    var.catalog_locations,
    [
      {
        type   = "url"
        target = "https://github.com/backstage/software-templates/blob/main/scaffolder-templates/react-ssr-template/template.yaml"
      }
    ]
  )

  app_config = {
    app = {
      title   = var.app_title
      baseUrl = "https://${var.hostname}"
    }
    backend = {
      baseUrl = "https://${var.hostname}"
      cors = {
        origin      = "https://${var.hostname}"
        methods     = ["GET", "HEAD", "PATCH", "POST", "PUT", "DELETE"]
        credentials = true
      }
      auth = {
        keys = [
          {
            secret = "$${BACKEND_SECRET}"
          }
        ]
      }
    }
    integrations = {
      github = [
        {
          host  = "github.com"
          token = "$${GITHUB_TOKEN}"
        }
      ]
    }
    catalog = {
      locations = [
        for location in local.catalog_locations : {
          type   = location.type
          target = location.target
          rules = [
            {
              allow = [
                "API",
                "Component",
                "Domain",
                "Group",
                "Location",
                "Resource",
                "System",
                "Template",
                "User"
              ]
            }
          ]
        }
      ]
    }
  }

  helm_values = {
    ingress = {
      enabled   = true
      className = var.ingress_class_name
      host      = var.hostname
      path      = "/"
      annotations = {
        "alb.ingress.kubernetes.io/scheme"          = var.ingress_scheme
        "alb.ingress.kubernetes.io/target-type"     = "ip"
        "external-dns.alpha.kubernetes.io/hostname" = var.hostname
      }
    }
    backstage = {
      extraAppConfig = [
        {
          filename     = "app-config.extra.yaml"
          configMapRef = local.app_config_name
        }
      ]
      extraEnvVarsSecrets = [
        local.backend_secret_name
      ]
    }
    postgresql = {
      enabled = true
      auth = {
        database = "backstage"
        username = "backstage"
      }
    }
    extraDeploy = [
      {
        apiVersion = "v1"
        kind       = "Secret"
        metadata = {
          name      = local.backend_secret_name
          namespace = var.namespace
        }
        type = "Opaque"
        stringData = {
          BACKEND_SECRET = local.backstage_backend_secret
          GITHUB_TOKEN   = var.github_token
        }
      },
      {
        apiVersion = "v1"
        kind       = "ConfigMap"
        metadata = {
          name      = local.app_config_name
          namespace = var.namespace
        }
        data = {
          "app-config.extra.yaml" = yamlencode(local.app_config)
        }
      }
    ]
  }
}

resource "random_password" "backend_secret" {
  length  = 40
  special = false
}

resource "helm_release" "backstage" {
  name             = var.release_name
  repository       = "https://backstage.github.io/charts"
  chart            = "backstage"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  values = [yamlencode(local.helm_values)]
}
