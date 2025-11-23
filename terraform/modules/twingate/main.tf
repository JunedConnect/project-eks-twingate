#provider block here is required otherwise initialisation will not work as Terraform will default to hashicorp/twingate rather than twingate/twingate
terraform {
  required_providers {
    twingate = {
      source  = "twingate/twingate"
    }
  }
}

resource "aws_key_pair" "ec2" {
  key_name   = "ec2-key"
  public_key = file("~/.ssh/playground.pub")
}

resource "aws_security_group" "ec2_instance" { # these are the best practices for the the Twingate Connector security group (https://www.twingate.com/docs/connector-best-practices)
  name        = "twingate-ec2-connector"
  description = "twingate-ec2-connector"
  vpc_id      = var.vpc_id

  # Outbound TCP Port 443 (basic communication with Twingate Controller and Relay infrastructure)
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound TCP Ports 30000-31000 (opening connections with Twingate Relay infrastructure)
  egress {
    from_port   = 30000
    to_port     = 31000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound UDP and QUIC for HTTP/3 (allows for peer-to-peer connectivity) Ports 1-65535
  egress {
    from_port   = 1
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "twingate_remote_network" "aws" {
  name = "aws-network"
  location = "AWS"
}

resource "twingate_remote_network" "eks" {
  name = "eks-network"
  location = "OTHER"
}

resource "twingate_connector" "aws_ec2" {
  name = "aws-ec2-connector"
  remote_network_id = twingate_remote_network.aws.id
}

resource "twingate_connector_tokens" "aws_ec2" {
  connector_id = twingate_connector.aws_ec2.id
}

resource "twingate_resource" "eks_api_endpoint" {
  name               = "eks-api-endpoint"
  remote_network_id  = twingate_remote_network.aws.id
  address            = replace(var.eks_cluster_endpoint, "https://", "")
  access_group {
    group_id = var.twingate_access_group_id
  }
}

data "aws_ami" "twingate" {
#   most_recent = true
  filter {
    name = "name"
    values = [
      var.twingate_ami_name,
    ]
  }
  owners = ["617935088040"]
}

resource "aws_instance" "twingate_connector" {
  ami           = data.aws_ami.twingate.id
  instance_type = "t3.micro"
  key_name = aws_key_pair.ec2.key_name

  vpc_security_group_ids  = [aws_security_group.ec2_instance.id]

  subnet_id              = var.private_subnet_1_id

  user_data = <<-EOT
    #!/bin/bash
    set -e
    mkdir -p /etc/twingate/
    {
      echo TWINGATE_URL="${var.twingate_url}"
      echo TWINGATE_ACCESS_TOKEN="${twingate_connector_tokens.aws_ec2.access_token}"
      echo TWINGATE_REFRESH_TOKEN="${twingate_connector_tokens.aws_ec2.refresh_token}"
    } > /etc/twingate/connector.conf
    sudo systemctl enable --now twingate-connector
  EOT
}


# kubernetes connector and resource below (only use if you want to use the twingate connector helm chart)

resource "twingate_connector" "kubernetes" {
  name = "kubernetes-connector-1"
  remote_network_id = twingate_remote_network.eks.id
}

resource "twingate_resource" "kubernetes_all" {
  name               = "kubernetes-all-1"
  remote_network_id  = twingate_remote_network.eks.id
  address            = "*.cluster.local"
  access_group {
    group_id = var.twingate_access_group_id
  }
}