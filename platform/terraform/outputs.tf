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
