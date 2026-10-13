variable "hosted_zone_id" {
  description = "ID of the externally managed public Route 53 hosted zone."
  type        = string
}

variable "domain_name" {
  description = "Apex domain to serve and include in the ACM certificate."
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name of the ALB with its HTTPS listener ready."
  type        = string
}

variable "alb_zone_id" {
  description = "ALB canonical hosted zone ID used by the Route 53 alias."
  type        = string
}
