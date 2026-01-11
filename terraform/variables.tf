# Required
variable "cluster_prefix" {
  type = string
}

variable "cloudstack_ccm_api_key" {
  type        = string
  sensitive   = true
  description = "CloudStack API key for the Cloud Controller Manager (CCM). Provide via -var parameter."
}

variable "cloudstack_ccm_secret_key" {
  type        = string
  sensitive   = true
  description = "CloudStack secret key for the Cloud Controller Manager (CCM). Provide via -var parameter."
}

variable "k3s_version" {
  type = string
}

variable "base_domain" {
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
