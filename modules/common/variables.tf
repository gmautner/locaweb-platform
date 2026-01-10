# =============================================================================
# REQUIRED VARIABLES
# =============================================================================

variable "charts_path" {
  type        = string
  description = "Path to the local charts directory."
}

variable "cert_manager_email" {
  type        = string
  description = "Email address for Let's Encrypt certificate notifications."
}

# =============================================================================
# OPTIONAL VARIABLES
# =============================================================================

variable "ingress_class_name" {
  type        = string
  default     = "traefik"
  description = "Name of the ingress class to create."
}

variable "ingress_ip_address" {
  type        = string
  default     = ""
  description = "IP address for the ingress load balancer. Leave empty for dynamic assignment."
}

variable "ingress_proxy_protocol_enabled" {
  type        = bool
  default     = true
  description = "Enable PROXY protocol for ingress."
}

variable "ingress_proxy_protocol_trusted_ips" {
  type        = list(string)
  default     = []
  description = "List of trusted IPs for PROXY protocol. Empty list enables insecure mode."
}

variable "k8up_timezone" {
  type        = string
  default     = "UTC"
  description = "Timezone for k8up backups."
}

