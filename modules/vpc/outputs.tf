output "vpc_id" {
  value = module.vpc.vpc_id
}
output "private_subnets" {
  value = module.vpc.private_subnets
}
output "intra_subnets" {
  value = module.vpc.intra_subnets
}
output "database_subnets" {
  value = module.vpc.database_subnets
}
output "default_security_group_id" {
  value = module.vpc.default_security_group_id
}
output "default_db_subnet_group_id" {
  value = module.vpc.database_subnet_group
}
output "default_elasticache_subnet_group_id" {
  value = module.vpc.elasticache_subnet_group
}