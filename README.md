# Terraform AWS (K8s Tunnel)

Provisions an EC2 instance in `eu-north-1` that acts as a WireGuard tunnel endpoint
and HTTP/S reverse proxy for the homelab K8s cluster. Optionally creates Cloudflare
DNS records (`tunnel.k8s.benrachmiel.org`, `*.k8s.benrachmiel.org`) pointing to
the instance.

## Directory Structure

```
provisioning/          Terraform config for the EC2 instance + DNS
configuration-ansible/ Ansible playbook to configure WireGuard + HAProxy on the instance
```

## Prerequisites

- AWS credentials configured (`~/.aws/credentials` or `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`)
- SSH keypair at `~/.ssh/id_ed25519_aws.pub` (configurable in `terraform.tfvars`)
- Terraform installed

## Instance Configuration

Edit `provisioning/terraform.tfvars` to change instance sizing:

```hcl
aws_region          = "eu-north-1"
instance_type       = "t3.micro"
ami                 = "ami-073130f74f5ffb161"
cpu_credits         = "standard"
root_volume_size    = 8
ssh_public_key_path = "~/.ssh/id_ed25519_aws.pub"
wireguard_port      = 51820
```

## Usage

### EC2 only (no Vault or Cloudflare)

If you just want to spin up the EC2 instance without Vault secrets or Cloudflare DNS,
use `-target` to provision only the AWS resources:

```bash
cd provisioning
terraform init
terraform apply \
  -target=aws_key_pair.ssh_key \
  -target=aws_security_group.tunnel \
  -target=aws_instance.tunnel
```

This skips all Vault data sources and Cloudflare DNS records. You'll get a bare
EC2 instance with SSH, HTTP/S, and WireGuard ports open.

### Full stack (requires Vault + Cloudflare)

Set up the required environment variables:

```bash
export VAULT_ADDR="https://vault.apps.okd.benrachmiel.org"
export VAULT_TOKEN="<your-vault-token>"
export CLOUDFLARE_API_TOKEN=$(vault kv get -field=token secret/cloudflare/api-token)
```

Then apply everything:

```bash
cd provisioning
terraform init
terraform apply
```

## Vault Integration

The full deployment reads secrets from Vault. These must be populated before running:

### `secret/wireguard/keys`

WireGuard keypairs (shared with `ansible-k8s-cilium`):

| Key | Description |
|-----|-------------|
| `ec2_private` | EC2 tunnel endpoint private key |
| `ec2_public` | EC2 tunnel endpoint public key |
| `node1_public` | K8s node 1 public key |
| `node2_public` | K8s node 2 public key |
| `node3_public` | K8s node 3 public key |

### `secret/wireguard/config`

WireGuard IP assignments for the tunnel mesh:

| Key | Description |
|-----|-------------|
| `ec2_ip` | EC2 WireGuard interface address (e.g. `10.10.0.1`) |
| `node1_ip` | K8s node 1 tunnel IP (`10.10.0.11`) |
| `node2_ip` | K8s node 2 tunnel IP (`10.10.0.12`) |
| `node3_ip` | K8s node 3 tunnel IP (`10.10.0.13`) |

```bash
vault kv put secret/wireguard/config \
  ec2_ip="10.10.0.1" \
  node1_ip="10.10.0.11" \
  node2_ip="10.10.0.12" \
  node3_ip="10.10.0.13"
```

### `secret/cloudflare/api-token`

| Key | Description |
|-----|-------------|
| `token` | Cloudflare API token with DNS edit access to `benrachmiel.org` |

## Cloudflare Integration

When Vault and Cloudflare are configured, Terraform creates two DNS records:

| Record | Type | Content |
|--------|------|---------|
| `tunnel.k8s.benrachmiel.org` | A | EC2 public IP |
| `*.k8s.benrachmiel.org` | A | EC2 public IP |

## Configuring the Instance (Ansible)

After provisioning, configure WireGuard and HAProxy on the instance:

```bash
cd configuration-ansible
ansible-playbook -i <ec2-public-ip>, -u ubuntu playbook.yml
```

This requires `VAULT_TOKEN` to be set (pulls WireGuard keys and config from Vault).

## Outputs

| Output | Description |
|--------|-------------|
| `instance_public_ip` | EC2 public IP address |
| `instance_public_dns` | EC2 public DNS name |
| `wireguard_ec2_public_key` | EC2 WireGuard public key (sensitive) |
| `tunnel_dns` | `tunnel.k8s.benrachmiel.org` |
