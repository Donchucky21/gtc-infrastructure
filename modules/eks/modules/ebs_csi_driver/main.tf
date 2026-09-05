locals {
  service_account_name = "ebs-csi-driver"
  namespace            = "kube-system"
  policy_arn           = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  # Changes based on Region - This is for us-east-1 Additional Reference: https://docs.aws.amazon.com/eks/latest/userguide/add-ons-images.html
  # This will throw an error if you don't use us-east-1, so if you need to add a region use the docs to match the correct image repo.
  image_repository = {
    us-east-1 = "602401143452.dkr.ecr.us-east-1.amazonaws.com/eks/aws-ebs-csi-driver"
    eu-west-1 = "602401143452.dkr.ecr.eu-west-1.amazonaws.com/eks/aws-ebs-csi-driver"
    eu-west-2 = "602401143452.dkr.ecr.eu-west-2.amazonaws.com/eks/aws-ebs-csi-driver"
  }
}

resource "kubernetes_service_account" "this" {
  metadata {
    name      = local.service_account_name
    namespace = local.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = module.iam_eks_role.arn
    }
  }
}

data "aws_iam_policy" "this" {
  arn = local.policy_arn
}

module "iam_eks_role" {
  source          = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version         = "~> 6.0.0"
  name            = "${var.cluster_name}-${local.service_account_name}"
  use_name_prefix = false

  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  policies = {
    policy = data.aws_iam_policy.this.arn
  }

  oidc_providers = {
    one = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["${local.namespace}:${local.service_account_name}"]
    }
  }
}

resource "helm_release" "ebs_csi_driver" {
  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  namespace  = "kube-system"
  version    = "2.49.1"
  atomic     = true
  timeout    = 600

  set {
    name  = "image.repository"
    value = local.image_repository[var.region]
  }

  # It still seems to be creating a service account and I'm not clear on why, but this works at the moment.
  set {
    name  = "controller.serviceAccount.create"
    value = "false"
  }

  set {
    name  = "controller.serviceAccount.name"
    value = local.service_account_name
  }

  set {
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.iam_eks_role.arn
  }

  depends_on = [kubernetes_service_account.this]
}

resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    encrypted = "true"
  }

  depends_on = [helm_release.ebs_csi_driver]
}
