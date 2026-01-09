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

variable "cert_manager_acme_server" {
  type        = string
  default     = "https://acme-v02.api.letsencrypt.org/directory"
  description = "ACME server URL for cert-manager."
}

variable "cert_manager_private_key_secret_name" {
  type        = string
  default     = "letsencrypt-http-prod"
  description = "Name of the Kubernetes secret for the ACME private key."
}

variable "k8up_timezone" {
  type        = string
  default     = "UTC"
  description = "Timezone for k8up backups."
}

