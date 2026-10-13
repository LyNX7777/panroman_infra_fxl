data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["137112412989"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "web" {
  name        = "${var.project_name}-web"
  description = "Allow public HTTP traffic to the demo web server"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-web"
  }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.web.id
  description       = "Public HTTP"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.web.id
  description       = "Package installation and container image download"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_eip" "web" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-web"
  }
}

resource "aws_eip_association" "web" {
  allocation_id = aws_eip.web.id
  instance_id   = aws_instance.web.id
}

resource "aws_instance" "web" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.web.id]

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    index_html_base64 = base64encode(var.index_html_content)
  })
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    delete_on_termination = true
    encrypted             = true
    volume_size           = 8
    volume_type           = "gp3"
  }

  tags = {
    Name = "${var.project_name}-web"
  }
}
