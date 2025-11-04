variable "region" {
  type    = string
  default = "us-east-1"
}

variable "key_name" {
  type = string
}

variable "ssh_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

variable "amazon_linux_ami_id" {
  type    = string
  default = null
}

variable "ubuntu_ami_id" {
  type    = string
  default = null
}

# ✅ FIXED: Use static relative path, no interpolation allowed
variable "inventory_output_path" {
  type    = string
  default = "../ansible/inventory.generated.yaml"
}
