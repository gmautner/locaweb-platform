locals {
  control_plane_ip_effective = cloudstack_instance.controlplane[0].ip_address

  k8s_api_endpoint = local.api_lb_ip_address

  api_lb_ip_address_id = cloudstack_ipaddress.api_lb.id
  api_lb_ip_address    = cloudstack_ipaddress.api_lb.ip_address

  ingress_ip_address_id = cloudstack_ipaddress.ingress.id
  ingress_ip_address    = cloudstack_ipaddress.ingress.ip_address

  k3s_controlplane_user_data = templatefile("${path.module}/templates/k3s-controlplane.yaml.tmpl", {
    k3s_token              = random_password.k3s_token.result
    control_plane_tls_sans  = [local.k8s_api_endpoint]
    control_plane_taints    = var.control_plane_taints
    control_plane_labels    = concat(["cluster=${var.cluster_name}"], var.control_plane_labels)
    disable_components      = var.disable_components
    disable_kube_proxy      = var.disable_kube_proxy
    disable_cloud_controller = var.disable_cloud_controller
    disable_network_policy  = var.disable_network_policy
    embedded_registry       = var.embedded_registry
    flannel_backend         = var.flannel_backend
    kube_apiserver_args     = local.kube_apiserver_args
  })

  k3s_agent_user_data = templatefile("${path.module}/templates/k3s-agent.yaml.tmpl", {
    control_plane_ip = local.k8s_api_endpoint
    k3s_token         = random_password.k3s_token.result
    agent_labels      = concat(["cluster=${var.cluster_name}"], var.agent_labels)
    flannel_backend   = var.flannel_backend
    agent_taints      = var.agent_taints
  })

  kubeconfig_path      = var.kubeconfig_output_path != "" ? var.kubeconfig_output_path : "/tmp/${var.cluster_name}-kubeconfig.yaml"
  ssh_private_key_path = var.ssh_private_key_path != "" ? var.ssh_private_key_path : "/tmp/${var.cluster_name}-ssh-key"

  k3s_artifacts_dir  = "/tmp/${var.cluster_name}-k3s-artifacts"
  k3s_install_script = "${local.k3s_artifacts_dir}/k3s-install.sh"
  k3s_binary_name = lookup({
    amd64 = "k3s"
    arm64 = "k3s-arm64"
    arm   = "k3s-armhf"
  }, var.k3s_arch, "k3s")
  k3s_binary_path  = "${local.k3s_artifacts_dir}/${local.k3s_binary_name}"
  k3s_images_name  = "k3s-airgap-images-${var.k3s_arch}.tar"
  k3s_images_path  = "${local.k3s_artifacts_dir}/${local.k3s_images_name}"

  kube_apiserver_args = concat(
    var.k3s_kube_apiserver_args,
    var.oidc_issuer_url != "" && var.oidc_client_id != "" ? [
      "oidc-issuer-url=${var.oidc_issuer_url}",
      "oidc-client-id=${var.oidc_client_id}",
      "oidc-username-claim=${var.oidc_username_claim}",
      "oidc-username-prefix=${var.oidc_username_prefix}"
    ] : []
  )
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

resource "cloudstack_network" "cluster" {
  name             = var.cluster_name
  cidr             = var.network_cidr
  network_offering = var.network_offering
  zone             = var.cloudstack_zone
  network_domain   = var.network_domain
  source_nat_ip    = true
  tags             = var.tags
}

resource "cloudstack_ipaddress" "api_lb" {
  zone = var.cloudstack_zone
  network_id  = cloudstack_network.cluster.id
}

resource "cloudstack_ipaddress" "ingress" {
  zone = var.cloudstack_zone
  network_id  = cloudstack_network.cluster.id
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
  network_id    = cloudstack_network.cluster.id
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
  network_id       = cloudstack_network.cluster.id
  ip_address       = null
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
  network_id       = cloudstack_network.cluster.id
  ip_address       = null
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

resource "terraform_data" "k3s_artifacts" {
  triggers_replace = {
    k3s_version = var.k3s_version
    k3s_arch    = var.k3s_arch
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<EOT
      set -e

      mkdir -p "${local.k3s_artifacts_dir}"
      curl -fsSL "${var.k3s_install_url}" -o "${local.k3s_install_script}"
      curl -fsSL "https://github.com/k3s-io/k3s/releases/download/${var.k3s_version}/${local.k3s_binary_name}" -o "${local.k3s_binary_path}"
      curl -fsSL "https://github.com/k3s-io/k3s/releases/download/${var.k3s_version}/${local.k3s_images_name}" -o "${local.k3s_images_path}"
      chmod +x "${local.k3s_install_script}"
    EOT
  }
}

resource "terraform_data" "k3s_upload_controlplane" {
  for_each = { for idx, inst in cloudstack_instance.controlplane : idx => inst }

  triggers_replace = {
    k3s_version = var.k3s_version
    k3s_arch    = var.k3s_arch
  }

  depends_on = [
    terraform_data.k3s_artifacts,
    cloudstack_instance.controlplane,
    local_file.ssh_private_key
  ]

  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = each.value.ip_address
    private_key = tls_private_key.ssh_key.private_key_openssh
  }

  provisioner "file" {
    source      = local.k3s_install_script
    destination = "/tmp/k3s-install.sh"
  }

  provisioner "file" {
    source      = local.k3s_binary_path
    destination = "/tmp/${local.k3s_binary_name}"
  }

  provisioner "file" {
    source      = local.k3s_images_path
    destination = "/tmp/${local.k3s_images_name}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /var/lib/rancher/k3s/agent/images",
      "sudo install -m 0755 /tmp/${local.k3s_binary_name} /usr/local/bin/k3s",
      "sudo install -m 0755 /tmp/k3s-install.sh /usr/local/bin/k3s-install.sh",
      "sudo mv /tmp/${local.k3s_images_name} /var/lib/rancher/k3s/agent/images/${local.k3s_images_name}",
      "sudo INSTALL_K3S_SKIP_DOWNLOAD=true INSTALL_K3S_EXEC='server' /usr/local/bin/k3s-install.sh"
    ]
  }
}

resource "terraform_data" "k3s_upload_agent" {
  for_each = { for idx, inst in cloudstack_instance.agent : idx => inst }

  triggers_replace = {
    k3s_version = var.k3s_version
    k3s_arch    = var.k3s_arch
  }

  depends_on = [
    terraform_data.k3s_artifacts,
    cloudstack_instance.agent,
    local_file.ssh_private_key,
    terraform_data.k3s_upload_controlplane
  ]

  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = each.value.ip_address
    private_key = tls_private_key.ssh_key.private_key_openssh
  }

  provisioner "file" {
    source      = local.k3s_install_script
    destination = "/tmp/k3s-install.sh"
  }

  provisioner "file" {
    source      = local.k3s_binary_path
    destination = "/tmp/${local.k3s_binary_name}"
  }

  provisioner "file" {
    source      = local.k3s_images_path
    destination = "/tmp/${local.k3s_images_name}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /var/lib/rancher/k3s/agent/images",
      "sudo install -m 0755 /tmp/${local.k3s_binary_name} /usr/local/bin/k3s",
      "sudo install -m 0755 /tmp/k3s-install.sh /usr/local/bin/k3s-install.sh",
      "sudo mv /tmp/${local.k3s_images_name} /var/lib/rancher/k3s/agent/images/${local.k3s_images_name}",
      "sudo INSTALL_K3S_SKIP_DOWNLOAD=true INSTALL_K3S_EXEC='agent' /usr/local/bin/k3s-install.sh"
    ]
  }
}

resource "terraform_data" "k3s_kubeconfig" {
  depends_on = [
    cloudstack_instance.controlplane,
    local_file.ssh_private_key,
    terraform_data.k3s_upload_controlplane
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

resource "terraform_data" "k3s_ready" {
  depends_on = [
    terraform_data.k3s_kubeconfig,
    helm_release.cilium,
    cloudstack_instance.controlplane,
    cloudstack_instance.agent,
    terraform_data.k3s_upload_agent
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<EOT
      set -e

      export KUBECONFIG="${local.kubeconfig_path}"
      EXPECTED=$(( ${var.control_plane_count} + ${var.agent_count} ))
      TIMEOUT_SEC=$(( ${var.k3s_ready_timeout_minutes} * 60 ))
      START_TS=$(date +%s)

      if ! command -v jq >/dev/null 2>&1; then
        echo "jq is required for readiness checks but was not found in PATH"
        exit 1
      fi

      while true; do
        READY_COUNT=$(kubectl get nodes -o json 2>/dev/null | jq '[.items[] | select(.status.conditions[]? | select(.type=="Ready" and .status=="True"))] | length')
        TOTAL_COUNT=$(kubectl get nodes -o json 2>/dev/null | jq '.items | length')

        if [ "$TOTAL_COUNT" -eq "$EXPECTED" ] && [ "$READY_COUNT" -eq "$EXPECTED" ]; then
          exit 0
        fi

        NOW_TS=$(date +%s)
        if [ $((NOW_TS - START_TS)) -ge "$TIMEOUT_SEC" ]; then
          echo "Timed out waiting for nodes. Ready: $READY_COUNT, Total: $TOTAL_COUNT, Expected: $EXPECTED"
          exit 1
        fi

        echo "Waiting for nodes: Ready ${READY_COUNT}/${EXPECTED}, Total ${TOTAL_COUNT}/${EXPECTED}"
        sleep 10
      done
    EOT
  }
}
