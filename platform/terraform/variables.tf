variable "cluster_name" {
  type        = string
  description = "Cluster name used for tagging and labeling."
}

variable "control_plane_ip" {
  type        = string
  default     = ""
  description = "Control plane IP address used by agents and tls-san. Leave empty to use control_plane_ips[0]."
  validation {
    condition     = var.control_plane_ip != "" || length(var.control_plane_ips) > 0
    error_message = "Either control_plane_ip must be set or control_plane_ips must include at least one IP."
  }
}

variable "control_plane_ips" {
  type        = list(string)
  default     = []
  description = "Optional list of fixed IPs for control plane instances."
}

variable "agent_ips" {
  type        = list(string)
  default     = []
  description = "Optional list of fixed IPs for agent instances."
}

variable "control_plane_count" {
  type        = number
  default     = 1
  description = "Number of control plane instances."
}

variable "agent_count" {
  type        = number
  default     = 2
  description = "Number of agent instances."
}

variable "cloudstack_zone" {
  type        = string
  description = "CloudStack zone name."
}

variable "cloudstack_api_url" {
  type        = string
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

variable "traefik_namespace" {
  type        = string
  default     = "traefik"
  description = "Namespace for Traefik."
}

variable "cert_manager_namespace" {
  type        = string
  default     = "cert-manager"
  description = "Namespace for cert-manager."
}

variable "cilium_namespace" {
  type        = string
  default     = "kube-system"
  description = "Namespace for Cilium."
}

variable "kured_namespace" {
  type        = string
  default     = "kube-system"
  description = "Namespace for kured."
}

variable "k8up_namespace" {
  type        = string
  default     = "k8up"
  description = "Namespace for k8up."
}

variable "cloudstack_namespace" {
  type        = string
  default     = "cloudstack-system"
  description = "Namespace for CloudStack CCM and CSI."
}

variable "system_upgrade_namespace" {
  type        = string
  default     = "system-upgrade"
  description = "Namespace for system-upgrade-controller and k3s upgrade plans."
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

variable "cloudstack_network_id" {
  type        = string
  description = "CloudStack network ID for instances."
}

variable "cloudstack_template" {
  type        = string
  description = "CloudStack template name or ID."
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
  description = "CloudStack service offering for control plane nodes."
}

variable "agent_service_offering" {
  type        = string
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

variable "k3s_version" {
  type        = string
  description = "Pinned k3s version to install (required)."
  validation {
    condition     = length(var.k3s_version) > 0
    error_message = "k3s_version must be set to a specific version."
  }
}

variable "control_plane_tls_sans" {
  type        = list(string)
  default     = []
  description = "Additional TLS SANs for the control plane."
}

variable "control_plane_taints" {
  type        = list(string)
  default     = ["node-role.kubernetes.io/control-plane=true:NoSchedule"]
  description = "Taints applied to control plane nodes."
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
  default     = ["servicelb", "traefik"]
  description = "k3s components to disable by default."
}

variable "flannel_backend" {
  type        = string
  default     = "none"
  description = "Flannel backend setting. Use 'none' when Cilium is the CNI."
}
