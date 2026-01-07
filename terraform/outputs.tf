output "cluster_name" {
  value       = module.cluster.cluster_name
  description = "Generated cluster name (slug + random suffix)."
}

output "control_plane_instance_ids" {
  value       = module.cluster.control_plane_instance_ids
  description = "CloudStack instance IDs for control plane nodes."
}

output "agent_instance_ids" {
  value       = module.cluster.agent_instance_ids
  description = "CloudStack instance IDs for agent nodes."
}

output "control_plane_ip_used" {
  value       = module.cluster.control_plane_ip_used
  description = "Control plane IP used by agents and tls-san."
}

output "api_lb_public_ip" {
  value       = module.cluster.api_lb_public_ip
  description = "Public IP for the Kubernetes API load balancer, when enabled."
}

output "ingress_public_ip" {
  value       = module.cluster.ingress_public_ip
  description = "Public IP reserved for ingress."
}

output "kubeconfig_path" {
  value       = module.cluster.kubeconfig_path
  description = "Local path to the generated kubeconfig."
}

output "kubeconfig" {
  value       = module.cluster.kubeconfig
  description = "Kubeconfig content (sensitive). Empty if not yet generated."
  sensitive   = true
}

output "ssh_private_key_path" {
  value       = module.cluster.ssh_private_key_path
  description = "Local path to the generated SSH private key."
}

output "ssh_private_key" {
  value       = module.cluster.ssh_private_key
  description = "Generated SSH private key (sensitive)."
  sensitive   = true
}
