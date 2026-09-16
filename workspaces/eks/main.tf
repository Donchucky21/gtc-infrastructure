locals {
  region      = var.region
  client      = "chucky-infra"
  environment = var.environment
  name        = "${local.client}-${local.environment}"
  tags = {
    "Environment" = local.environment
    "Client"      = local.client
    "name"        = "ap"
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name     = local.name
  vpc_cidr = var.vpc_cidr
  tags     = local.tags
}

module "eks" {
  source = "../../modules/eks"

  cluster_name       = local.name
  kubernetes_version = var.eks_cluster_version
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnets
  min_nodes          = var.min_nodes
  max_nodes          = var.max_nodes
  desired_size       = var.desired_size
  admin_principal_arns = concat(
    var.eks_admin_principal_arns,
    [aws_iam_role.github_app_deployer.arn]
  )
  tags = local.tags
}

module "route53_zone" {
  source    = "../../modules/route53_zone"
  zone_name = var.zone
}

module "ebs_csi_driver" {
  source            = "../../modules/eks/modules/ebs_csi_driver"
  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  region            = local.region

  providers = {
    kubernetes = kubernetes
    helm       = helm
  }

  depends_on = [module.eks]
}

module "aws_load_balancer_controller" {
  source            = "../../modules/eks/modules/aws_load_balancer_controller"
  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  domain_name       = module.route53_zone.domain_name
  r53_zone_id       = module.route53_zone.zone_id
  tags              = local.tags
  region            = local.region
  vpc_id            = module.eks.vpc_id

  providers = {
    kubernetes = kubernetes
    helm       = helm
  }

  depends_on = [module.eks, module.route53_zone, module.ebs_csi_driver]
}

module "external_dns" {
  source            = "../../modules/eks/modules/external_dns"
  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn

  providers = {
    kubernetes = kubernetes
    helm       = helm
  }

  depends_on = [module.eks, module.aws_load_balancer_controller]
}

module "external_secrets" {
  source             = "../../modules/eks/modules/external_secrets"
  cluster_name       = module.eks.cluster_name
  oidc_provider_arn  = module.eks.oidc_provider_arn
  ssm_parameter_arns = var.external_secrets_ssm_parameter_arns
  kms_key_arns       = var.external_secrets_kms_key_arns

  providers = {
    helm = helm
  }

  depends_on = [module.eks, module.aws_load_balancer_controller]
}

# module "github_actions_runner" {
#   source = "../../modules/eks/modules/github_actions_runner"

#   github_config_url     = var.github_runner_config_url
#   github_token          = var.github_runner_token
#   runner_scale_set_name = var.github_runner_scale_set_name
#   min_runners           = var.github_runner_min_runners
#   max_runners           = var.github_runner_max_runners

#   providers = {
#     helm = helm
#   }

#   depends_on = [module.eks, module.aws_load_balancer_controller]
# }

module "monitoring" {
  source = "../../modules/eks/modules/monitoring"

  cluster_name = module.eks.cluster_name
  region       = local.region

  depends_on = [module.eks, module.ebs_csi_driver, module.aws_load_balancer_controller]
}
