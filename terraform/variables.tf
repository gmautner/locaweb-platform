# Required
variable "cluster_name" {
  type = string
}

variable "cloudstack_api_key" {
  type      = string
  sensitive = true
}

variable "cloudstack_secret_key" {
  type      = string
  sensitive = true
}

variable "k3s_version" {
  type = string
}

# Optional
variable "options" {
  default = {}
}

# Advanced
variable "advanced" {
  default = {}
}
