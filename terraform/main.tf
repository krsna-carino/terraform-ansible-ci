data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

locals {
  subnet_id = data.aws_subnets.default.ids[0]
}

data "aws_ami" "amzn2" {
  most_recent = true
  owners      = ["137112412989"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# ✅ Use Ubuntu 22.04 LTS (Jammy)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}


resource "aws_security_group" "demo" {
  name        = "tf-ansible-demo"
  description = "Allow SSH, HTTP, and Netdata"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 19999
    to_port     = 19999
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "frontend" {
  ami                    = var.amazon_linux_ami_id != null ? var.amazon_linux_ami_id : data.aws_ami.amzn2.id
  instance_type          = "t3.micro"
  subnet_id              = local.subnet_id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.demo.id]

  tags = {
    Name = "c8.local"
    Role = "frontend"
  }

  user_data = <<-EOF
              #!/bin/bash
              hostnamectl set-hostname c8.local
              EOF
}

resource "aws_instance" "backend" {
  ami                    = var.ubuntu_ami_id != null ? var.ubuntu_ami_id : data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = local.subnet_id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.demo.id]

  tags = {
    Name = "u22.local"
    Role = "backend"
  }

  user_data = <<-EOF
              #!/bin/bash
              hostnamectl set-hostname u22.local
              EOF
}


data "template_file" "inventory" {
  template = file("${path.module}/templates/inventory.yaml.tmpl")

  vars = {
    frontend_host = aws_instance.frontend.public_ip
    backend_host  = aws_instance.backend.public_ip
  }
}

resource "local_file" "inventory" {
  filename = var.inventory_output_path
  content  = data.template_file.inventory.rendered
}
