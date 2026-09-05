module "argocd" {
  source = "../../modules/argocd"

  hostname               = coalesce(var.argocd_hostname, "argocd.${var.zone}")
  github_account         = var.github_account
  github_pat_token       = var.github_pat_token
  github_repository_url  = var.github_repository_url
  github_revision        = var.github_revision
  gitops_root_path       = var.gitops_root_path
  argocd_deployment_name = var.argocd_deployment_name

  application_destination_namespace = var.application_destination_namespace
  bootstrap_destination_namespace   = var.bootstrap_destination_namespace
  ingress_certificate_arn           = var.ingress_certificate_arn

  providers = {
    helm = helm
  }
}
