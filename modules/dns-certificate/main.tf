locals {
  domain_name = trimsuffix(lower(var.domain_name), ".")
}

# The zone and its existing ACM validation records remain externally owned.
data "aws_route53_zone" "existing" {
  zone_id      = var.hosted_zone_id
  private_zone = false

  lifecycle {
    postcondition {
      condition     = !self.private_zone && trimsuffix(lower(self.name), ".") == local.domain_name
      error_message = "hosted_zone_id must identify the public hosted zone for the requested apex domain."
    }
  }
}

data "aws_route53_records" "existing" {
  zone_id = data.aws_route53_zone.existing.zone_id
}

resource "aws_route53_record" "application" {
  zone_id         = data.aws_route53_zone.existing.zone_id
  name            = local.domain_name
  type            = "A"
  ttl             = 300
  records         = [var.public_ip]
  allow_overwrite = false
}

resource "aws_acm_certificate" "application" {
  domain_name       = local.domain_name
  validation_method = "DNS"
  key_algorithm     = "RSA_2048"

  options {
    export = "DISABLED"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "application" {
  certificate_arn = aws_acm_certificate.application.arn
  validation_record_fqdns = [
    for option in aws_acm_certificate.application.domain_validation_options : option.resource_record_name
  ]

  lifecycle {
    precondition {
      condition = alltrue([
        for option in aws_acm_certificate.application.domain_validation_options : anytrue([
          for record in data.aws_route53_records.existing.resource_record_sets :
          trimsuffix(lower(record.name), ".") == trimsuffix(lower(option.resource_record_name), ".") &&
          record.type == option.resource_record_type &&
          length(record.resource_records) == 1 &&
          anytrue([
            for value in record.resource_records :
            trimsuffix(lower(value.value), ".") == trimsuffix(lower(option.resource_record_value), ".")
          ])
        ])
      ])
      error_message = "The existing hosted zone must contain the exact ACM validation CNAME name, type, and value requested by this certificate. Reconcile the externally managed validation record before retrying; this project will not overwrite or adopt it."
    }
  }
}
