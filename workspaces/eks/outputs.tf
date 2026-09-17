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

output "github_app_deployer_role_arn" {
  description = "IAM role used by the application GitHub Actions workflow"
  value       = aws_iam_role.github_app_deployer.arn
}