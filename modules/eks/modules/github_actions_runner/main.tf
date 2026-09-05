locals {
  chart_repository            = "oci://ghcr.io/actions/actions-runner-controller-charts"
  github_token_value          = trimspace(coalesce(nonsensitive(var.github_token), " "))
  github_secret_name_value    = trimspace(coalesce(var.github_config_secret_name, " "))
  github_token_provided       = local.github_token_value != ""
  github_secret_name_provided = local.github_secret_name_value != ""

  runner_values = merge(
    {
      githubConfigUrl    = var.github_config_url
      runnerScaleSetName = var.runner_scale_set_name
      minRunners         = var.min_runners
      maxRunners         = var.max_runners
    },
    local.github_secret_name_provided ? {
      githubConfigSecret = local.github_secret_name_value
    } : {}
  )
}

resource "helm_release" "controller" {
  name             = var.controller_release_name
  repository       = local.chart_repository
  chart            = "gha-runner-scale-set-controller"
  namespace        = var.controller_namespace
  create_namespace = true
  version          = var.chart_version
}

resource "helm_release" "runner_scale_set" {
  name             = var.runner_scale_set_name
  repository       = local.chart_repository
  chart            = "gha-runner-scale-set"
  namespace        = var.runner_namespace
  create_namespace = true
  version          = var.chart_version
  values           = [yamlencode(local.runner_values)]

  dynamic "set_sensitive" {
    for_each = local.github_token_provided ? [1] : []
    content {
      name  = "githubConfigSecret.github_token"
      value = var.github_token
    }
  }

  lifecycle {
    precondition {
      condition     = local.github_token_provided != local.github_secret_name_provided
      error_message = "Set exactly one of github_token or github_config_secret_name for the GitHub Actions runner scale set."
    }
  }

  depends_on = [helm_release.controller]
}
