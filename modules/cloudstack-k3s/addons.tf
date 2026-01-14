locals {
  charts_path = "${path.module}/../../charts"
}

# =============================================================================
# COMMON ADDONS (traefik, cert-manager, k8up)
# =============================================================================

module "common" {
  source = "../common"

  charts_path        = local.charts_path
  cert_manager_email = var.options.cert_manager_email

  ingress_class_name                 = local.ingress_class_name
  ingress_ip_address                 = local.ingress_ip_address
  ingress_proxy_protocol_enabled     = local.ingress_proxy_protocol_enabled
  ingress_proxy_protocol_trusted_ips = local.ingress_proxy_protocol_trusted_ips

  cluster_name  = local.cluster_name
  enable_backup = var.options.enable_backup

  depends_on = [terraform_data.k3s_ready, helm_release.cloudstack_ccm, helm_release.cloudstack_csi]
}

# =============================================================================
# K3S-SPECIFIC ADDONS
# =============================================================================

resource "helm_release" "system_upgrade_controller" {
  name       = "system-upgrade-controller"
  repository = "https://charts.rancher.io"
  chart      = "system-upgrade-controller"
  version    = "~> 108.0.0"
  namespace  = "system-upgrade"

  create_namespace = true

  depends_on = [terraform_data.k3s_ready]
}

resource "helm_release" "k3s_upgrade_plans" {
  name      = "k3s-upgrade-plans"
  chart     = "${local.charts_path}/k3s-upgrade-plans"
  namespace = "system-upgrade"

  create_namespace = false

  values = [
    yamlencode({
      k3sVersion                    = var.k3s_version
      serverConcurrency             = local.k3s_upgrade_server_concurrency
      agentConcurrency              = local.k3s_upgrade_agent_concurrency
      drainForce                    = local.k3s_upgrade_drain_force
      drainSkipWaitForDeleteTimeout = local.k3s_upgrade_drain_skip_wait_for_delete_timeout
    })
  ]

  depends_on = [helm_release.system_upgrade_controller, terraform_data.k3s_ready]
}

# =============================================================================
# CLOUDSTACK-SPECIFIC ADDONS
# =============================================================================

resource "helm_release" "cloudstack_ccm" {
  name      = "cloudstack-ccm"
  chart     = "${local.charts_path}/cloudstack-ccm"
  namespace = "cloudstack-system"

  create_namespace = true

  values = [
    yamlencode({
      apiUrl    = var.advanced.cloudstack_api_url
      apiKey    = var.cloudstack_ccm_api_key
      secretKey = var.cloudstack_ccm_secret_key
    })
  ]

  depends_on = [helm_release.cilium, terraform_data.k3s_ready]
}

resource "helm_release" "cloudstack_csi" {
  name      = "cloudstack-csi"
  chart     = "${local.charts_path}/cloudstack-csi"
  namespace = "cloudstack-system"

  create_namespace = true

  depends_on = [helm_release.cloudstack_ccm, terraform_data.k3s_ready]
}

resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io"
  chart      = "cilium"
  version    = "~> 1.18.5"
  namespace  = "kube-system"

  create_namespace = true

  values = [
    yamlencode({
      k8sServiceHost                      = local.k8s_api_endpoint
      k8sServicePort                      = local.k8s_service_port
      kubeProxyReplacement                = true
      kubeProxyReplacementHealthzBindAddr = "0.0.0.0:10256"
      routingMode                         = "tunnel"
      bpf = {
        policyMapMax = 65536
      }
      socketLB = {
        hostNamespaceOnly = true
      }
      resources = {
        requests = {
          cpu    = "75m"
          memory = "1Gi"
        }
        limits = {
          cpu    = "1"
          memory = "1Gi"
        }
      }
      operator = {
        resources = {
          requests = {
            cpu    = "40m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }
      hubble = {
        relay = {
          enabled = true
          resources = {
            requests = {
              cpu    = "20m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }
        }
        ui = {
          enabled = true
          backend = {
            resources = {
              requests = {
                cpu    = "20m"
                memory = "256Mi"
              }
              limits = {
                cpu    = "250m"
                memory = "256Mi"
              }
            }
          }
          frontend = {
            resources = {
              requests = {
                cpu    = "20m"
                memory = "256Mi"
              }
              limits = {
                cpu    = "250m"
                memory = "256Mi"
              }
            }
          }
        }
        metrics = {
          enabled = [
            "policy:sourceContext=app|workload-name|pod|reserved-identity;destinationContext=app|workload-name|pod|dns|reserved-identity;labelsContext=source_namespace,destination_namespace"
          ]
        }
      }
    })
  ]

  depends_on = [terraform_data.k3s_kubeconfig]
}

resource "helm_release" "kured" {
  name       = "kured"
  repository = "https://kubereboot.github.io/charts"
  chart      = "kured"
  version    = "~> 5.10.0"
  namespace  = "kube-system"

  create_namespace = true

  values = [
    yamlencode({
      configuration = {
        startTime = var.options.kured_start_time
        endTime   = var.options.kured_end_time
        timeZone  = var.options.kured_time_zone
        period    = local.kured_period
      }
      tolerations = [
        {
          key      = "CriticalAddonsOnly"
          operator = "Exists"
        },
        {
          operator = "Exists"
          effect   = "NoSchedule"
        }
      ]
      resources = {
        requests = {
          cpu    = "20m"
          memory = "160Mi"
        }
        limits = {
          cpu    = "250m"
          memory = "256Mi"
        }
      }
    })
  ]

  depends_on = [helm_release.cilium, terraform_data.k3s_ready]
}
