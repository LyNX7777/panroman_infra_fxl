variable "hosted_zone_id" {
  description = "ID of the externally managed public Route 53 hosted zone."
  type        = string
}

variable "domain_name" {
  description = "Apex domain to serve and include in the ACM certificate."
  type        = string
}

variable "public_ip" {
  description = "Elastic IPv4 address to publish in the apex A record."
  type        = string
}
