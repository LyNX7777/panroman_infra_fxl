module "network" {
  source = "../modules/network"

  project_name                 = var.project_name
  vpc_cidr                     = var.vpc_cidr
  public_subnet_cidr           = var.public_subnet_cidr
  secondary_public_subnet_cidr = var.secondary_public_subnet_cidr
}

module "web_server" {
  source = "../modules/web-server"

  project_name                    = var.project_name
  vpc_id                          = module.network.vpc_id
  subnet_id                       = module.network.public_subnet_id
  instance_type                   = var.instance_type
  index_html_content              = file("${path.module}/../app/index.html")
  load_balancer_security_group_id = module.load_balancer.security_group_id
}

module "dns_certificate" {
  source = "../modules/dns-certificate"

  hosted_zone_id = var.hosted_zone_id
  domain_name    = var.domain_name
  alb_dns_name   = module.load_balancer.dns_name
  alb_zone_id    = module.load_balancer.zone_id
}

module "load_balancer" {
  source = "../modules/load-balancer"

  project_name          = var.project_name
  vpc_id                = module.network.vpc_id
  public_subnet_ids     = module.network.public_subnet_ids
  certificate_arn       = module.dns_certificate.certificate_arn
  instance_id           = module.web_server.instance_id
  web_security_group_id = module.web_server.security_group_id
}
