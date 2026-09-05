locals {
  policy_name = "${var.cluster_name}-${var.service_account_name}"
}

data "aws_iam_policy_document" "external_secrets" {
  statement {
    sid = "ListParameterStore"
    actions = [
      "ssm:DescribeParameters"
    ]
    resources = ["*"]
  }

  statement {
    sid = "ReadParameterStore"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = var.ssm_parameter_arns
  }

  statement {
    sid = "DecryptSecureStringParameters"
    actions = [
      "kms:Decrypt"
    ]
    resources = var.kms_key_arns
  }
}

resource "aws_iam_policy" "external_secrets" {
  name   = local.policy_name
  policy = data.aws_iam_policy_document.external_secrets.json
}

module "iam_eks_role" {
  source          = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version         = "~> 6.0.0"
  name            = local.policy_name
  use_name_prefix = false

  policies = {
    policy = aws_iam_policy.external_secrets.arn
  }

  oidc_providers = {
    one = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["${var.namespace}:${var.service_account_name}"]
    }
  }
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = var.namespace
  create_namespace = true
  version          = var.chart_version
  atomic           = true
  timeout          = 600

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = var.service_account_name
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.iam_eks_role.arn
  }
}
