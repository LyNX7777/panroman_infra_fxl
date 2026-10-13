mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = { names = ["eu-central-1a", "eu-central-1b"] }
  }

  mock_data "aws_ami" {
    defaults = { id = "ami-0123456789abcdef0" }
  }

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

  mock_resource "aws_lb" {
    defaults = {
      arn      = "arn:aws:elasticloadbalancing:eu-central-1:123456789012:loadbalancer/app/demo/1234567890abcdef"
      dns_name = "demo.eu-central-1.elb.amazonaws.com"
      zone_id  = "Z215JYRZR1TBD5"
    }
  }

  mock_resource "aws_lb_target_group" {
    defaults = { arn = "arn:aws:elasticloadbalancing:eu-central-1:123456789012:targetgroup/demo/1234567890abcdef" }
  }

  mock_resource "aws_route53_record" {
    defaults = { fqdn = "panroman.pl" }
  }
}

run "complete_https_graph" {
  command = apply

  variables {
    aws_account_id = "123456789012"
  }

  assert {
    condition     = output.application_url == "https://panroman.pl" && output.alb_dns_name == "demo.eu-central-1.elb.amazonaws.com"
    error_message = "The complete dependency graph must publish HTTPS through the ALB."
  }
}

run "two_public_availability_zones" {
  command = apply

  module { source = "../modules/network" }

  variables {
    project_name                 = "demo"
    vpc_cidr                     = "10.0.0.0/16"
    public_subnet_cidr           = "10.0.1.0/24"
    secondary_public_subnet_cidr = "10.0.2.0/24"
  }

  assert {
    condition = (
      aws_subnet.public.availability_zone != aws_subnet.public_secondary.availability_zone &&
      aws_subnet.public.cidr_block == "10.0.1.0/24" &&
      aws_subnet.public_secondary.cidr_block == "10.0.2.0/24" &&
      aws_route_table_association.public.route_table_id == aws_route_table_association.public_secondary.route_table_id &&
      length(output.public_subnet_ids) == 2
    )
    error_message = "Preserve the original subnet and route both AZs through the same internet gateway."
  }
}

run "listeners_targets_and_firewall" {
  command = apply

  module { source = "../modules/load-balancer" }

  variables {
    project_name          = "demo"
    vpc_id                = "vpc-0123456789abcdef0"
    public_subnet_ids     = ["subnet-0123456789abcdef0", "subnet-1123456789abcdef0"]
    certificate_arn       = "arn:aws:acm:eu-central-1:123456789012:certificate/test"
    instance_id           = "i-0123456789abcdef0"
    web_security_group_id = "sg-0123456789abcdef0"
  }

  assert {
    condition = (
      !aws_lb.application.internal && aws_lb.application.ip_address_type == "ipv4" &&
      aws_lb.application.load_balancer_type == "application" &&
      aws_lb_listener.https.port == 443 && aws_lb_listener.https.protocol == "HTTPS" &&
      aws_lb_listener.https.certificate_arn == var.certificate_arn &&
      aws_lb_listener.https.ssl_policy == "ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09" &&
      one(aws_lb_listener.https.default_action).target_group_arn == aws_lb_target_group.nginx.arn &&
      aws_lb_target_group.nginx.protocol == "HTTP" && aws_lb_target_group.nginx.port == 80 &&
      aws_lb_target_group.nginx.target_type == "instance" &&
      aws_lb_target_group.nginx.health_check[0].path == "/" &&
      aws_lb_target_group.nginx.health_check[0].matcher == "200" &&
      aws_lb_target_group_attachment.nginx.target_id == var.instance_id
    )
    error_message = "TLS must terminate at the ALB and forward HTTP to the healthy instance target."
  }

  assert {
    condition = (
      aws_lb_listener.http.port == 80 &&
      one(aws_lb_listener.http.default_action).type == "redirect" &&
      one(one(aws_lb_listener.http.default_action).redirect).status_code == "HTTP_301" &&
      one(one(aws_lb_listener.http.default_action).redirect).protocol == "HTTPS" &&
      one(one(aws_lb_listener.http.default_action).redirect).port == "443" &&
      one(one(aws_lb_listener.http.default_action).redirect).host == "#{host}" &&
      one(one(aws_lb_listener.http.default_action).redirect).path == "/#{path}" &&
      one(one(aws_lb_listener.http.default_action).redirect).query == "#{query}"
    )
    error_message = "HTTP must redirect permanently to HTTPS preserving host, path, and query."
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.public["http"].from_port == 80 &&
      aws_vpc_security_group_ingress_rule.public["https"].from_port == 443 &&
      alltrue([for rule in aws_vpc_security_group_ingress_rule.public : rule.cidr_ipv4 == "0.0.0.0/0" && rule.ip_protocol == "tcp" && rule.to_port == rule.from_port]) &&
      aws_vpc_security_group_egress_rule.nginx.referenced_security_group_id == var.web_security_group_id &&
      aws_vpc_security_group_egress_rule.nginx.from_port == 80 &&
      aws_vpc_security_group_egress_rule.nginx.to_port == 80 &&
      aws_vpc_security_group_egress_rule.nginx.cidr_ipv4 == null
    )
    error_message = "The ALB must accept public web traffic and send only HTTP to the web security group."
  }
}

run "origin_rejects_direct_public_http" {
  command = apply

  module { source = "../modules/web-server" }

  variables {
    project_name                    = "demo"
    vpc_id                          = "vpc-0123456789abcdef0"
    subnet_id                       = "subnet-0123456789abcdef0"
    instance_type                   = "t3.micro"
    index_html_content              = "<h1>Demo</h1>"
    load_balancer_security_group_id = "sg-1123456789abcdef0"
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.http.referenced_security_group_id == var.load_balancer_security_group_id &&
      aws_vpc_security_group_ingress_rule.http.cidr_ipv4 == null &&
      aws_vpc_security_group_ingress_rule.http.from_port == 80 &&
      aws_vpc_security_group_ingress_rule.http.to_port == 80 &&
      aws_instance.web.associate_public_ip_address
    )
    error_message = "Only the ALB may reach Nginx; retain automatic public IPv4 for outbound bootstrapping."
  }
}
