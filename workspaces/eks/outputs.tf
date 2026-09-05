output "eks" {
  value = module.eks
}

output "grafana_admin_password" {
  value     = module.monitoring.grafana_admin_password
  sensitive = true
}

output "external_secrets" {
  value = {
    namespace            = module.external_secrets.namespace
    service_account_name = module.external_secrets.service_account_name
    iam_role_arn         = module.external_secrets.iam_role_arn
    iam_policy_arn       = module.external_secrets.iam_policy_arn
  }
}

output "github_actions_runner" {
  value = {
    runner_scale_set_name = module.github_actions_runner.runner_scale_set_name
    runner_namespace      = module.github_actions_runner.runner_namespace
    controller_namespace  = module.github_actions_runner.controller_namespace
  }
}
