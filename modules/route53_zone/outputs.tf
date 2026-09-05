output "arn" {
  value = data.aws_route53_zone.dns_zone.arn
}
output "name_servers" {
  value = data.aws_route53_zone.dns_zone.name_servers
}
output "zone_id" {
  value = data.aws_route53_zone.dns_zone.zone_id
}
output "domain_name" {
  value = data.aws_route53_zone.dns_zone.name
}
