output "control_plane_instance_ids" {
  value       = [for instance in cloudstack_instance.controlplane : instance.id]
  description = "CloudStack instance IDs for control plane nodes."
}

output "agent_instance_ids" {
  value       = [for instance in cloudstack_instance.agent : instance.id]
  description = "CloudStack instance IDs for agent nodes."
}

output "control_plane_ip_used" {
  value       = local.control_plane_ip_effective
  description = "Control plane IP used by agents and tls-san."
}

output "api_lb_public_ip" {
  value       = local.api_lb_ip_address
  description = "Public IP for the Kubernetes API load balancer, when enabled."
}

output "ingress_public_ip" {
  value       = local.ingress_ip_address
  description = "Public IP reserved for ingress."
}

output "kubeconfig_path" {
  value       = local.kubeconfig_path
  description = "Local path to the generated kubeconfig."
}

output "kubeconfig" {
  value       = try(file(local.kubeconfig_path), "")
  description = "Kubeconfig content (sensitive). Empty if not yet generated."
  sensitive   = true
}

output "ssh_private_key_path" {
  value       = local.ssh_private_key_path
  description = "Local path to the generated SSH private key."
}

output "ssh_private_key" {
  value       = tls_private_key.ssh_key.private_key_openssh
  description = "Generated SSH private key (sensitive)."
  sensitive   = true
}

