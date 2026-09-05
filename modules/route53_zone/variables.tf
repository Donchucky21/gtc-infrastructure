variable "zone_name" {
  type        = string
  description = "Name of the existing Route53 hosted zone to look up."
}

variable "private_zone" {
  type        = bool
  description = "Whether to look up a private hosted zone."
  default     = false
}
