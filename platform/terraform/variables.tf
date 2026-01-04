variable "cluster_name" {
  type        = string
  description = "Cluster name used for tagging and labeling."
}

variable "control_plane_count" {
  type        = number
  default     = 3
  description = "Number of control plane instances."
  validation {
    condition     = contains([1, 3], var.control_plane_count)
    error_message = "control_plane_count must be 1 or 3."
  }
}

variable "agent_count" {
  type        = number
  default     = 4
  description = "Number of agent instances."
  validation {
    condition     = var.agent_count >= 3
    error_message = "agent_count must be at least 3."
  }
}

variable "cloudstack_zone" {
  type        = string
  default     = "ZP01"
  description = "CloudStack zone name."
}

variable "network_cidr" {
  type        = string
  default     = "192.168.0.0/21"
  description = "CIDR for the CloudStack network created per cluster."
}

variable "network_offering" {
  type        = string
  default     = "c39d7786-2967-4b18-948e-a97d605cbf89"
  description = "CloudStack network offering to use."
}

variable "network_domain" {
  type        = string
  default     = "cluster.local"
  description = "Network domain for the CloudStack network."
}
variable "cloudstack_api_url" {
  type        = string
  default     = "https://painel-cloud.locaweb.com.br/client/api"
  description = "CloudStack API endpoint."
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

variable "ssh_user" {
  type        = string
  default     = "root"
  description = "SSH user for control plane access."
}

variable "kubeconfig_output_path" {
  type        = string
  default     = ""
  description = "Path to write the generated kubeconfig. Leave empty to use /tmp."
}

variable "ssh_private_key_path" {
  type        = string
  default     = ""
  description = "Path to write the generated SSH private key. Leave empty to use /tmp."
}

variable "k3s_upgrade_server_concurrency" {
  type        = number
  default     = 1
  description = "Concurrency for k3s server upgrades."
}

variable "k3s_upgrade_agent_concurrency" {
  type        = number
  default     = 2
  description = "Concurrency for k3s agent upgrades."
}

variable "k3s_upgrade_drain_force" {
  type        = bool
  default     = true
  description = "Force drain during k3s agent upgrades."
}

variable "k3s_upgrade_drain_skip_wait_for_delete_timeout" {
  type        = number
  default     = 60
  description = "Skip wait for delete timeout during k3s agent drain."
}

variable "k3s_ready_timeout_minutes" {
  type        = number
  default     = 15
  description = "Timeout in minutes to wait for all k3s nodes to be Ready."
}

variable "cert_manager_email" {
  type        = string
  description = "Email used for ACME registration."
}

variable "cert_manager_acme_server" {
  type        = string
  default     = "https://acme-v02.api.letsencrypt.org/directory"
  description = "ACME server URL for cert-manager."
}

variable "cert_manager_private_key_secret_name" {
  type        = string
  default     = "letsencrypt-http-prod"
  description = "Secret name for the ACME account private key."
}

variable "k8s_service_port" {
  type        = number
  default     = 6443
  description = "Kubernetes API port for Cilium k8sServicePort."
}

variable "kured_start_time" {
  type        = string
  default     = "5:00"
  description = "Kured reboot window start time (HH:MM)."
}

variable "kured_end_time" {
  type        = string
  default     = "6:59"
  description = "Kured reboot window end time (HH:MM)."
}

variable "kured_time_zone" {
  type        = string
  default     = "UTC"
  description = "Kured timezone for reboot window."
}

variable "kured_period" {
  type        = string
  default     = "15m"
  description = "Kured reboot check period."
}

variable "ingress_class_name" {
  type        = string
  default     = "traefik"
  description = "IngressClass name for Traefik."
}

variable "ingress_proxy_protocol_enabled" {
  type        = bool
  default     = true
  description = "Enable PROXY protocol on Traefik entrypoints."
}

variable "ingress_proxy_protocol_trusted_ips" {
  type        = list(string)
  default     = []
  description = "Trusted IPs for PROXY protocol headers. Leave empty to allow any source."
}


variable "cloudstack_template" {
  type        = string
  description = "CloudStack template name or ID."
}

variable "cloudstack_offerings" {
  type        = list(string)
  default     = ["micro", "small", "medium", "large", "xlarge", "2xlarge", "4xlarge"]
  description = "Allowed CloudStack service offerings."
}

variable "api_lb_allowed_cidrs" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "CIDRs allowed to access the API load balancer."
}

variable "ingress_allowed_cidrs" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "CIDRs allowed to access ingress on ports 80/443."
}

variable "control_plane_service_offering" {
  type        = string
  default     = "large"
  description = "CloudStack service offering for control plane nodes."
}

variable "agent_service_offering" {
  type        = string
  default     = "xlarge"
  description = "CloudStack service offering for agent nodes."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to CloudStack instances."
}

variable "expunge" {
  type        = bool
  default     = true
  description = "Whether to expunge instances on destroy."
}

variable "k3s_install_url" {
  type        = string
  default     = "https://get.k3s.io"
  description = "Install script URL for k3s."
}

variable "k3s_arch" {
  type        = string
  default     = "amd64"
  description = "k3s architecture for binary and airgap images (amd64, arm64, arm)."
  validation {
    condition     = contains(["amd64", "arm64", "arm"], var.k3s_arch)
    error_message = "k3s_arch must be one of: amd64, arm64, arm."
  }
}

variable "k3s_version" {
  type        = string
  description = "Pinned k3s version to install (required)."
  validation {
    condition     = length(var.k3s_version) > 0
    error_message = "k3s_version must be set to a specific version."
  }
}

variable "control_plane_taints" {
  type        = list(string)
  default     = ["node-role.kubernetes.io/control-plane=true:NoSchedule", "CriticalAddonsOnly=true:NoExecute"]
  description = "Taints applied to control plane nodes."
}

variable "agent_taints" {
  type        = list(string)
  default     = ["node.cilium.io/agent-not-ready=true:NoExecute"]
  description = "Taints applied to agent nodes."
}

variable "control_plane_labels" {
  type        = list(string)
  default     = ["k3s-upgrade=true"]
  description = "Labels applied to control plane nodes."
}

variable "agent_labels" {
  type        = list(string)
  default     = ["node-role.kubernetes.io/worker=true", "k3s-upgrade=true"]
  description = "Labels applied to agent nodes."
}

variable "disable_components" {
  type        = list(string)
  default     = ["servicelb", "traefik", "local-storage"]
  description = "k3s components to disable by default."
}

variable "disable_kube_proxy" {
  type        = bool
  default     = true
  description = "Disable kube-proxy in k3s."
}

variable "disable_cloud_controller" {
  type        = bool
  default     = true
  description = "Disable in-tree cloud controller in k3s."
}

variable "disable_network_policy" {
  type        = bool
  default     = true
  description = "Disable built-in network policy controller in k3s."
}

variable "embedded_registry" {
  type        = bool
  default     = true
  description = "Enable embedded registry in k3s."
}

variable "k3s_kube_apiserver_args" {
  type        = list(string)
  default     = ["request-timeout=300s"]
  description = "Extra kube-apiserver arguments for k3s."
}

variable "oidc_issuer_url" {
  type        = string
  default     = ""
  description = "OIDC issuer URL for kube-apiserver."
}

variable "oidc_client_id" {
  type        = string
  default     = ""
  description = "OIDC client ID for kube-apiserver."
}

variable "oidc_username_claim" {
  type        = string
  default     = "preferred_username"
  description = "OIDC username claim for kube-apiserver."
}

variable "oidc_username_prefix" {
  type        = string
  default     = "oidc:"
  description = "OIDC username prefix for kube-apiserver."
}
variable "flannel_backend" {
  type        = string
  default     = "none"
  description = "Flannel backend setting. Use 'none' when Cilium is the CNI."
}
