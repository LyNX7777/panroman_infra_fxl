module "network" {
  source = "../modules/network"

  project_name       = var.project_name
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
}

module "web_server" {
  source = "../modules/web-server"

  project_name       = var.project_name
  vpc_id             = module.network.vpc_id
  subnet_id          = module.network.public_subnet_id
  instance_type      = var.instance_type
  index_html_content = file("${path.module}/../app/index.html")

  depends_on = [module.network]
}

module "dns_certificate" {
  source = "../modules/dns-certificate"

  hosted_zone_id = var.hosted_zone_id
  domain_name    = var.domain_name
  public_ip      = module.web_server.public_ip
}
