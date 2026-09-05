output "namespace" {
  value = var.namespace
}

output "service_account_name" {
  value = var.service_account_name
}

output "iam_role_arn" {
  value = module.iam_eks_role.arn
}

output "iam_policy_arn" {
  value = aws_iam_policy.external_secrets.arn
}
