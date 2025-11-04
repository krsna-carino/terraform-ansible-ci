# ✅ Get Default VPC and Subnets
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

# ✅ Get Amazon Linux 2 AMI
data "aws_ami" "amzn2" {
  most_recent = true
  owners      = ["137112412989"] # Amazon
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# ✅ Get Ubuntu 21.04 AMI (fallback)
data "aws_ami" "ubuntu_hirsute" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-hirsute-21.04-amd64-server-*"]
  }
}

# ✅ Security Group
resource "aws_security_group" "demo" {
  name        = "tf-ansible-demo"
  description = "Allow SSH, HTTP, and Netdata"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Netdata"
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

# ✅ Frontend Instance (Amazon Linux)
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

# ✅ Backend Instance (Ubuntu)
resource "aws_instance" "backend" {
  ami                    = var.ubuntu_ami_id != null ? var.ubuntu_ami_id : data.aws_ami.ubuntu_hirsute.id
  instance_type          = "t3.micro"
  subnet_id              = local.subnet_id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.demo.id]

  tags = {
    Name = "u21.local"
    Role = "backend"
  }

  user_data = <<-EOF
              #!/bin/bash
              hostnamectl set-hostname u21.local
              EOF
}

# ✅ Generate Dynamic Inventory File
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
