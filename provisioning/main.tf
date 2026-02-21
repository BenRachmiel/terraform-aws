terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "vault" {
  # VAULT_ADDR and VAULT_TOKEN from environment
}

provider "cloudflare" {
  # CLOUDFLARE_API_TOKEN from environment, or pull from Vault below
}

# --- Vault lookups ---

data "vault_kv_secret_v2" "wireguard_keys" {
  mount = "secret"
  name  = "wireguard/keys"
}

data "vault_kv_secret_v2" "wireguard_config" {
  mount = "secret"
  name  = "wireguard/config"
}

data "vault_kv_secret_v2" "cloudflare" {
  mount = "secret"
  name  = "cloudflare/api-token"
}

# --- Cloudflare zone lookup ---

data "cloudflare_zones" "benrachmiel" {
  filter {
    name = "benrachmiel.org"
  }
}

locals {
  cloudflare_zone_id = data.cloudflare_zones.benrachmiel.zones[0].id
}

# --- SSH key ---

resource "aws_key_pair" "ssh_key" {
  key_name   = "ec2-testing-key"
  public_key = file(var.ssh_public_key_path)
}

# --- Security group ---

resource "aws_security_group" "tunnel" {
  name        = "ec2-k8s-tunnel"
  description = "SSH + HTTP/S + WireGuard for K8s tunnel"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "WireGuard"
    from_port   = var.wireguard_port
    to_port     = var.wireguard_port
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- EC2 instance ---

resource "aws_instance" "tunnel" {
  ami           = var.ami
  instance_type = var.instance_type

  key_name               = aws_key_pair.ssh_key.key_name
  vpc_security_group_ids = [aws_security_group.tunnel.id]

  root_block_device {
    volume_size = var.root_volume_size
  }

  credit_specification {
    cpu_credits = var.cpu_credits
  }

  tags = {
    Name = "k8s-tunnel"
  }
}

# --- Cloudflare DNS ---

resource "cloudflare_record" "tunnel" {
  zone_id = local.cloudflare_zone_id
  name    = "tunnel.k8s"
  content = aws_instance.tunnel.public_ip
  type    = "A"
  ttl     = 60
  proxied = false
}

resource "cloudflare_record" "wildcard" {
  zone_id = local.cloudflare_zone_id
  name    = "*.k8s"
  content = aws_instance.tunnel.public_ip
  type    = "A"
  ttl     = 60
  proxied = false
}

# --- Outputs ---

output "instance_public_ip" {
  value = aws_instance.tunnel.public_ip
}

output "instance_public_dns" {
  value = aws_instance.tunnel.public_dns
}

output "wireguard_ec2_public_key" {
  value     = data.vault_kv_secret_v2.wireguard_keys.data["ec2_public"]
  sensitive = true
}

output "tunnel_dns" {
  value = "tunnel.k8s.benrachmiel.org"
}
