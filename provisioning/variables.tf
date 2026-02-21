variable "aws_region" {
  description = "AWS region for the EC2 instance"
  type        = string
  default     = "eu-north-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ami" {
  description = "AMI ID for the EC2 instance"
  type        = string
  default     = "ami-073130f74f5ffb161"
}

variable "cpu_credits" {
  description = "CPU credit specification (standard or unlimited)"
  type        = string
  default     = "standard"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 8
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key for EC2 access"
  type        = string
  default     = "~/.ssh/id_ed25519_aws.pub"
}

variable "wireguard_port" {
  description = "WireGuard listen port"
  type        = number
  default     = 51820
}
