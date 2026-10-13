mock_provider "aws" {
  mock_data "aws_route53_zone" {
    defaults = {
      zone_id      = "Z09698437FJB59WM71X"
      name         = "panroman.pl."
      private_zone = false
    }
  }

  mock_data "aws_route53_records" {
    defaults = {
      resource_record_sets = [{
        name             = "_validation.panroman.pl."
        type             = "CNAME"
        resource_records = [{ value = "_token.acm-validations.aws." }]
      }]
    }
  }

  mock_resource "aws_acm_certificate" {
    defaults = {
      arn = "arn:aws:acm:eu-central-1:123456789012:certificate/test"
      domain_validation_options = [{
        domain_name           = "panroman.pl"
        resource_record_name  = "_validation.panroman.pl."
        resource_record_type  = "CNAME"
        resource_record_value = "_token.acm-validations.aws."
      }]
    }
  }
}

variables {
  hosted_zone_id = "Z09698437FJB59WM71X"
  domain_name    = "panroman.pl"
  alb_dns_name   = "demo.eu-central-1.elb.amazonaws.com"
  alb_zone_id    = "Z215JYRZR1TBD5"
}

run "matching_external_validation_record" {
  command = apply

  module {
    source = "../modules/dns-certificate"
  }

  assert {
    condition = (
      aws_route53_record.application.name == "panroman.pl" &&
      aws_route53_record.application.type == "A" &&
      aws_route53_record.application.ttl == null &&
      aws_route53_record.application.records == null &&
      one(aws_route53_record.application.alias).name == var.alb_dns_name &&
      one(aws_route53_record.application.alias).zone_id == var.alb_zone_id &&
      one(aws_route53_record.application.alias).evaluate_target_health &&
      aws_route53_record.application.allow_overwrite == false
    )
    error_message = "Publish only the intended apex ALB alias without overwriting existing DNS."
  }

  assert {
    condition = (
      aws_acm_certificate.application.domain_name == "panroman.pl" &&
      aws_acm_certificate.application.validation_method == "DNS" &&
      aws_acm_certificate.application.key_algorithm == "RSA_2048" &&
      one(aws_acm_certificate.application.options).export == "DISABLED" &&
      output.certificate_arn == aws_acm_certificate.application.arn
    )
    error_message = "Issue a DNS-validated, non-exportable certificate for the apex domain."
  }
}

run "normalizes_dns_case_and_trailing_dots" {
  command = apply

  module {
    source = "../modules/dns-certificate"
  }

  override_data {
    target = data.aws_route53_records.existing
    values = {
      resource_record_sets = [{
        name             = "_VALIDATION.PANROMAN.PL"
        type             = "CNAME"
        resource_records = [{ value = "_TOKEN.ACM-VALIDATIONS.AWS" }]
      }]
    }
  }
}

run "rejects_missing_validation_record" {
  command = plan

  module {
    source = "../modules/dns-certificate"
  }

  override_data {
    target = data.aws_route53_records.existing
    values = { resource_record_sets = [] }
  }

  expect_failures = [aws_acm_certificate_validation.application]
}

run "rejects_conflicting_validation_value" {
  command = plan

  module {
    source = "../modules/dns-certificate"
  }

  override_data {
    target = data.aws_route53_records.existing
    values = {
      resource_record_sets = [{
        name             = "_validation.panroman.pl."
        type             = "CNAME"
        resource_records = [{ value = "_different.acm-validations.aws." }]
      }]
    }
  }

  expect_failures = [aws_acm_certificate_validation.application]
}

run "rejects_wrong_validation_name" {
  command = plan

  module {
    source = "../modules/dns-certificate"
  }

  override_data {
    target = data.aws_route53_records.existing
    values = {
      resource_record_sets = [{
        name             = "_other.panroman.pl."
        type             = "CNAME"
        resource_records = [{ value = "_token.acm-validations.aws." }]
      }]
    }
  }

  expect_failures = [aws_acm_certificate_validation.application]
}

run "rejects_wrong_validation_type" {
  command = plan

  module {
    source = "../modules/dns-certificate"
  }

  override_data {
    target = data.aws_route53_records.existing
    values = {
      resource_record_sets = [{
        name             = "_validation.panroman.pl."
        type             = "TXT"
        resource_records = [{ value = "_token.acm-validations.aws." }]
      }]
    }
  }

  expect_failures = [aws_acm_certificate_validation.application]
}

run "rejects_unrelated_zone" {
  command = plan

  module {
    source = "../modules/dns-certificate"
  }

  override_data {
    target = data.aws_route53_zone.existing
    values = {
      zone_id      = "Z09698437FJB59WM71X"
      name         = "other.example."
      private_zone = false
    }
  }

  expect_failures = [data.aws_route53_zone.existing]
}
