variable "oidc_provider_arn" {
  type = string
}
variable "cluster_name" {
  type = string
}
variable "domain_name" {
  type = string
}
variable "r53_zone_id" {
  type = string
}
variable "tags" {
  type = map(string)
}
variable "region" {
  type = string
}
variable "vpc_id" {
  type = string
}
