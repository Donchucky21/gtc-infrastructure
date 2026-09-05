locals {
  service_account_name            = "aws-load-balancer-controller"
  namespace                       = "kube-system"
  load_balancer_controller_policy = file("${path.module}/files/load_balancer_controller_policy.json")
}

resource "kubernetes_service_account" "load_balancer_controller" {
  metadata {
    name      = local.service_account_name
    namespace = local.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = module.iam_eks_role.arn
    }
  }
}

resource "aws_iam_policy" "load_balancer_controller" {
  name   = "${var.cluster_name}-${local.service_account_name}"
  policy = local.load_balancer_controller_policy
}

module "iam_eks_role" {
  source          = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version         = "~> 6.0.0"
  name            = "${var.cluster_name}-${local.service_account_name}"
  use_name_prefix = false

  policies = {
    policy = aws_iam_policy.load_balancer_controller.arn
  }

  oidc_providers = {
    one = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["${local.namespace}:${local.service_account_name}"]
    }
  }
}

resource "helm_release" "aws-load-balancer-controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  timeout    = 600
  atomic     = true

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = false
  }

  set {
    name  = "serviceAccount.name"
    value = local.service_account_name
  }

  depends_on = [kubernetes_service_account.load_balancer_controller]
}

module "acm" {
  source      = "terraform-aws-modules/acm/aws"
  version     = "~> 4.0"
  domain_name = var.domain_name
  zone_id     = var.r53_zone_id

  subject_alternative_names = [
    "*.${var.domain_name}"
  ]

  wait_for_validation = true
  tags                = var.tags
}
