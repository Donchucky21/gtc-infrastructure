output "backstage" {
  value = {
    namespace    = module.backstage.namespace
    release_name = module.backstage.release_name
    hostname     = module.backstage.hostname
  }
}
