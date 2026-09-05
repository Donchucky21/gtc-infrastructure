variable "name" {
  type        = string
  description = "Name of the VPC"
}
variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
}
variable "vpc_cidr" {
  type = string
}