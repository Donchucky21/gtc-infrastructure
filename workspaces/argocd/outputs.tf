output "argocd" {
  value = {
    namespace                   = module.argocd.namespace
    release_name                = module.argocd.release_name
    hostname                    = module.argocd.hostname
    bootstrap_application_name  = module.argocd.bootstrap_application_name
    bootstrap_path              = module.argocd.bootstrap_path
    applicationset_name         = module.argocd.applicationset_name
    applicationset_path         = module.argocd.applicationset_path
    server_port_forward_command = module.argocd.server_port_forward_command
  }
}
