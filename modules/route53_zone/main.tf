data "aws_route53_zone" "dns_zone" {
  name         = var.zone_name
  private_zone = var.private_zone
}
