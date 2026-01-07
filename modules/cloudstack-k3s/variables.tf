# =============================================================================
# REQUIRED VARIABLES
# =============================================================================

variable "cluster_prefix" {
  type        = string
  description = "Cluster prefix used to generate the cluster name with a random suffix."
}

variable "cloudstack_api_key" {
  type        = string
  sensitive   = true
  description = "CloudStack API key."
}

variable "cloudstack_secret_key" {
  type        = string
  sensitive   = true
  description = "CloudStack secret key."
}

variable "k3s_version" {
  type        = string
  description = "Pinned k3s version to install."
  validation {
    condition     = length(var.k3s_version) > 0
    error_message = "k3s_version must be set to a specific version."
  }
}

variable "base_domain" {
  type        = string
  description = "Base domain under which endpoints for externally accessible services will be created. Must be a DNS zone under your control."
  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$", var.base_domain))
    error_message = "base_domain must be a valid domain name (e.g., example.com or k8s.example.com)."
  }
}

# =============================================================================
# OPTIONAL VARIABLES
# =============================================================================

variable "options" {
  description = "Optional cluster configuration. All fields have sensible defaults."
  type = object({
    cloudstack_zone        = optional(string, "ZP01")
    control_plane_count    = optional(number, 3)
    agent_count            = optional(number, 4)
    agent_service_offering = optional(string, "xlarge")
    api_lb_allowed_cidrs   = optional(list(string), ["0.0.0.0/0"])
    ingress_allowed_cidrs  = optional(list(string), ["0.0.0.0/0"])
    tags                   = optional(map(string), {})
    oidc_issuer_url        = optional(string, "")
    oidc_client_id         = optional(string, "")
    oidc_username_claim    = optional(string, "preferred_username")
    cert_manager_email     = optional(string, "platform@locaweb.com.br")
    kured_start_time       = optional(string, "5:00")
    kured_end_time         = optional(string, "6:59")
    kured_time_zone        = optional(string, "UTC")
  })
  default = {}

  validation {
    condition     = contains([1, 3], var.options.control_plane_count)
    error_message = "control_plane_count must be 1 or 3."
  }

  validation {
    condition     = var.options.agent_count >= 3
    error_message = "agent_count must be at least 3."
  }
}

# =============================================================================
# ADVANCED VARIABLES
# =============================================================================

variable "advanced" {
  description = "Advanced cluster configuration. Only change if you know what you're doing."
  type = object({
    cloudstack_api_url             = optional(string, "https://painel-cloud.locaweb.com.br/client/api")
    cloudstack_template            = optional(string, "73253685-dcf5-42ec-ad7e-77482fa11e26")
    network_cidr                   = optional(string, "192.168.0.0/21")
    network_offering               = optional(string, "c39d7786-2967-4b18-948e-a97d605cbf89")
    network_domain                 = optional(string, "cluster.local")
    control_plane_service_offering = optional(string, "large")
    k3s_arch                       = optional(string, "amd64")
    kubeconfig_output_path         = optional(string, "")
    ssh_private_key_path           = optional(string, "")
  })
  default = {}

  validation {
    condition     = contains(["amd64"], var.advanced.k3s_arch)
    error_message = "k3s_arch must be: amd64."
  }
}
