locals {
  service_account_name = "external-dns"
  namespace            = "kube-system"
  # TODO: Restrict to supplied list of DNS zones if given.
  external_dns_policy = file("${path.module}/files/external_dns_policy.json")
}

resource "aws_iam_policy" "external_dns" {
  name   = "${var.cluster_name}-${local.service_account_name}"
  policy = local.external_dns_policy
}

module "iam_eks_role" {
  source          = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version         = "~> 6.0.0"
  name            = "${var.cluster_name}-${local.service_account_name}"
  use_name_prefix = false

  policies = {
    policy = aws_iam_policy.external_dns.arn
  }

  oidc_providers = {
    one = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["${local.namespace}:${local.service_account_name}"]
    }
  }
}

resource "kubernetes_service_account" "external_dns" {
  metadata {
    name      = local.service_account_name
    namespace = local.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = module.iam_eks_role.arn
    }
  }
}

resource "helm_release" "external-dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = "kube-system"
  version    = "1.14.2"
  atomic     = true
  timeout    = 600

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "image.repository"
    value = "registry.k8s.io/external-dns/external-dns"
  }

  set {
    name  = "serviceAccount.name"
    value = local.service_account_name
  }

  depends_on = [kubernetes_service_account.external_dns]
}

