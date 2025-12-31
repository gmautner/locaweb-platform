locals {
  control_plane_ip_effective = var.control_plane_ip != "" ? var.control_plane_ip : (
    length(var.control_plane_ips) > 0 ? var.control_plane_ips[0] : ""
  )

  k8s_api_endpoint = local.api_lb_ip_address

  api_lb_ip_address_id = cloudstack_ipaddress.api_lb.id
  api_lb_ip_address    = cloudstack_ipaddress.api_lb.ip_address

  ingress_ip_address_id = cloudstack_ipaddress.ingress.id
  ingress_ip_address    = cloudstack_ipaddress.ingress.ip_address

  k3s_controlplane_user_data = templatefile("${path.module}/templates/k3s-controlplane.yaml.tmpl", {
    k3s_token              = random_password.k3s_token.result
    k3s_install_url         = var.k3s_install_url
    k3s_version             = var.k3s_version
    control_plane_tls_sans  = concat([local.k8s_api_endpoint], var.control_plane_tls_sans)
    control_plane_taints    = var.control_plane_taints
    control_plane_labels    = concat(["cluster=${var.cluster_name}"], var.control_plane_labels)
    disable_components      = var.disable_components
    flannel_backend         = var.flannel_backend
  })

  k3s_agent_user_data = templatefile("${path.module}/templates/k3s-agent.yaml.tmpl", {
    control_plane_ip = local.k8s_api_endpoint
    k3s_token         = random_password.k3s_token.result
    k3s_install_url   = var.k3s_install_url
    k3s_version       = var.k3s_version
    agent_labels      = concat(["cluster=${var.cluster_name}"], var.agent_labels)
    flannel_backend   = var.flannel_backend
  })

  kubeconfig_path      = var.kubeconfig_output_path != "" ? var.kubeconfig_output_path : "/tmp/${var.cluster_name}-kubeconfig.yaml"
  ssh_private_key_path = var.ssh_private_key_path != "" ? var.ssh_private_key_path : "/tmp/${var.cluster_name}-ssh-key"
}

resource "random_password" "k3s_token" {
  length  = 32
  special = false
  upper   = true
  lower   = true
  numeric = true
}

resource "tls_private_key" "ssh_key" {
  algorithm = "ED25519"
}

resource "local_file" "ssh_private_key" {
  filename        = local.ssh_private_key_path
  content         = tls_private_key.ssh_key.private_key_openssh
  file_permission = "0600"
}

resource "cloudstack_ssh_keypair" "cluster" {
  name       = var.cluster_name
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "cloudstack_ipaddress" "api_lb" {
  zone = var.cloudstack_zone
}

resource "cloudstack_ipaddress" "ingress" {
  zone = var.cloudstack_zone
}

resource "cloudstack_firewall" "api_lb" {
  ip_address_id = local.api_lb_ip_address_id

  rule {
    cidr_list = var.api_lb_allowed_cidrs
    protocol  = "tcp"
    ports     = ["6443"]
  }
}

resource "cloudstack_firewall" "ingress" {
  ip_address_id = local.ingress_ip_address_id

  rule {
    cidr_list = var.ingress_allowed_cidrs
    protocol  = "tcp"
    ports     = ["80", "443"]
  }
}

resource "cloudstack_loadbalancer_rule" "api_lb" {
  name          = "${var.cluster_name}-kubeapi"
  ip_address_id = local.api_lb_ip_address_id
  network_id    = var.cloudstack_network_id
  algorithm     = "roundrobin"
  member_ids    = [for instance in cloudstack_instance.controlplane : instance.id]
  private_port  = 6443
  public_port   = 6443
  protocol      = "tcp"
}

resource "cloudstack_instance" "controlplane" {
  count = var.control_plane_count

  name             = "${var.cluster_name}-cp-${count.index + 1}"
  service_offering = var.control_plane_service_offering
  template         = var.cloudstack_template
  zone             = var.cloudstack_zone
  network_id       = var.cloudstack_network_id
  ip_address       = length(var.control_plane_ips) > count.index ? var.control_plane_ips[count.index] : null
  expunge          = var.expunge
  keypair          = cloudstack_ssh_keypair.cluster.name
  user_data        = base64encode(local.k3s_controlplane_user_data)
  tags = merge(
    var.tags,
    {
      cluster = var.cluster_name
      role    = "controlplane"
    }
  )
}

resource "cloudstack_instance" "agent" {
  count = var.agent_count

  name             = "${var.cluster_name}-worker-${count.index + 1}"
  service_offering = var.agent_service_offering
  template         = var.cloudstack_template
  zone             = var.cloudstack_zone
  network_id       = var.cloudstack_network_id
  ip_address       = length(var.agent_ips) > count.index ? var.agent_ips[count.index] : null
  expunge          = var.expunge
  keypair          = cloudstack_ssh_keypair.cluster.name
  user_data        = base64encode(local.k3s_agent_user_data)
  tags = merge(
    var.tags,
    {
      cluster = var.cluster_name
      role    = "worker"
    }
  )
}

resource "terraform_data" "k3s_kubeconfig" {
  depends_on = [
    cloudstack_instance.controlplane,
    local_file.ssh_private_key
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<EOT
      set -e

      SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
      KEY_FILE="${local_file.ssh_private_key.filename}"
      HOST="${local.control_plane_ip_effective}"

      for i in $(seq 1 60); do
        if ssh $SSH_OPTS -i "$KEY_FILE" "${var.ssh_user}@${HOST}" "test -f /etc/rancher/k3s/k3s.yaml"; then
          break
        fi
        sleep 10
      done

      ssh $SSH_OPTS -i "$KEY_FILE" "${var.ssh_user}@${HOST}" "sudo cat /etc/rancher/k3s/k3s.yaml" | \\
        sed "s/127.0.0.1/${local.k8s_api_endpoint}/g" > "${local.kubeconfig_path}"
    EOT
  }
}
