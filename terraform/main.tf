terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }

  required_version = ">= 1.6.0"
}

provider "aws" {
  region = "us-east-1"
}

# -----------------------------
# Find the default VPC
# -----------------------------

data "aws_vpc" "default" {
  default = true
}

# -----------------------------
# Find a subnet in the default VPC
# -----------------------------

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# -----------------------------
# Find the latest Ubuntu 24.04 AMI
# -----------------------------

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# -----------------------------
# Security Group
# -----------------------------

resource "aws_security_group" "devops_lab" {
  name        = "devops-vle-sg"
  description = "Security group for DevOps Virtual Lab"
  vpc_id      = data.aws_vpc.default.id

  # SSH - Ansible / administration
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubernetes NodePort range
  ingress {
    description = "Kubernetes NodePort"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "DevOps-VLE-SG"
  }
}

# -----------------------------
# EC2 Instance
# -----------------------------

resource "aws_instance" "devops_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.small"

  subnet_id = data.aws_subnets.default.ids[0]

  key_name = "devops-vle-key"

  vpc_security_group_ids = [
    aws_security_group.devops_lab.id
  ]

  tags = {
    Name = "DevOps-Lab-Server"
  }
}

# -----------------------------
# Outputs
# -----------------------------

output "instance_id" {
  value = aws_instance.devops_server.id
}

output "public_ip" {
  value = aws_instance.devops_server.public_ip
}

output "public_dns" {
  value = aws_instance.devops_server.public_dns
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/devops-vle-key.pem ubuntu@${aws_instance.devops_server.public_ip}"
}
