output "namespace" {
  value = var.namespace
}

output "release_name" {
  value = helm_release.backstage.name
}

output "hostname" {
  value = var.hostname
}
