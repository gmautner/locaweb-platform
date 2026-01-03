locals {
  ingress_proxy_protocol_insecure = var.ingress_proxy_protocol_enabled && length(var.ingress_proxy_protocol_trusted_ips) == 0
  traefik_values = merge(
    {
      ingressClass = {
        enabled        = true
        isDefaultClass = true
        name           = var.ingress_class_name
      }
      ports = {
        web = {
          proxyProtocol = {
            insecure   = local.ingress_proxy_protocol_insecure
            trustedIPs = var.ingress_proxy_protocol_trusted_ips
          }
        }
        websecure = {
          proxyProtocol = {
            insecure   = local.ingress_proxy_protocol_insecure
            trustedIPs = var.ingress_proxy_protocol_trusted_ips
          }
        }
      }
      service = {
        type = "LoadBalancer"
      }
    },
    {
      service = {
        type = "LoadBalancer"
        spec = {
          loadBalancerIP = local.ingress_ip_address
        }
      }
    }
  )
}

resource "helm_release" "traefik" {
  name       = "traefik"
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = "~> 38.0.1"
  namespace  = var.traefik_namespace

  create_namespace = true

  values = [yamlencode(local.traefik_values)]

  depends_on = [helm_release.cilium, terraform_data.k3s_ready]
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "~> 1.19.2"
  namespace  = var.cert_manager_namespace

  create_namespace = true

  values = [
    yamlencode({
      installCRDs = true
    })
  ]

  depends_on = [helm_release.cilium, terraform_data.k3s_ready]
}

resource "helm_release" "cert_manager_issuers" {
  name      = "cert-manager-issuers"
  chart     = "${path.module}/../../charts/cert-manager-issuers"
  namespace = var.cert_manager_namespace

  create_namespace = false

  values = [
    yamlencode({
      email            = var.cert_manager_email
      server           = var.cert_manager_acme_server
      privateKeySecretName = var.cert_manager_private_key_secret_name
      ingressClassName = var.ingress_class_name
    })
  ]

  depends_on = [helm_release.cert_manager, terraform_data.k3s_ready]
}

resource "helm_release" "system_upgrade_controller" {
  name       = "system-upgrade-controller"
  repository = "https://charts.rancher.io"
  chart      = "system-upgrade-controller"
  version    = "~> 108.0.0"
  namespace  = var.system_upgrade_namespace

  create_namespace = true

  depends_on = [terraform_data.k3s_ready]
}

resource "helm_release" "k3s_upgrade_plans" {
  name      = "k3s-upgrade-plans"
  chart     = "${path.module}/../../charts/k3s-upgrade-plans"
  namespace = var.system_upgrade_namespace

  create_namespace = false

  values = [
    yamlencode({
      k3sVersion                     = var.k3s_version
      serverConcurrency              = var.k3s_upgrade_server_concurrency
      agentConcurrency               = var.k3s_upgrade_agent_concurrency
      drainForce                     = var.k3s_upgrade_drain_force
      drainSkipWaitForDeleteTimeout  = var.k3s_upgrade_drain_skip_wait_for_delete_timeout
    })
  ]

  depends_on = [helm_release.system_upgrade_controller, terraform_data.k3s_ready]
}

resource "helm_release" "cloudstack_ccm" {
  name      = "cloudstack-ccm"
  chart     = "${path.module}/../../charts/cloudstack-ccm"
  namespace = var.cloudstack_namespace

  create_namespace = true

  values = [
    yamlencode({
      apiUrl    = var.cloudstack_api_url
      apiKey    = var.cloudstack_api_key
      secretKey = var.cloudstack_secret_key
    })
  ]

  depends_on = [helm_release.cilium, terraform_data.k3s_ready]
}

resource "helm_release" "cloudstack_csi" {
  name      = "cloudstack-csi"
  chart     = "${path.module}/../../charts/cloudstack-csi"
  namespace = var.cloudstack_namespace

  create_namespace = true

  depends_on = [helm_release.cloudstack_ccm, terraform_data.k3s_ready]
}

resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io"
  chart      = "cilium"
  version    = "~> 1.18.5"
  namespace  = var.cilium_namespace

  create_namespace = true

  values = [
    yamlencode({
      k8sServiceHost                     = local.k8s_api_endpoint
      k8sServicePort                     = var.k8s_service_port
      kubeProxyReplacement               = true
      kubeProxyReplacementHealthzBindAddr = "0.0.0.0:10256"
      routingMode                        = "tunnel"
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
}

resource "helm_release" "kured" {
  name       = "kured"
  repository = "https://kubereboot.github.io/charts"
  chart      = "kured"
  version    = "~> 5.10.0"
  namespace  = var.kured_namespace

  create_namespace = true

  values = [
    yamlencode({
      configuration = {
        startTime = var.kured_start_time
        endTime   = var.kured_end_time
        timeZone  = var.kured_time_zone
        period    = var.kured_period
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

resource "helm_release" "k8up" {
  name       = "k8up"
  repository = "https://k8up-io.github.io/k8up"
  chart      = "k8up"
  version    = "~> 4.8.6"
  namespace  = var.k8up_namespace

  create_namespace = true

  values = [
    yamlencode({
      k8up = {
        timezone = "UTC"
      }
      resources = {
        requests = {
          cpu    = "20m"
          memory = "128Mi"
        }
        limits = {
          memory = "256Mi"
        }
      }
    })
  ]

  depends_on = [helm_release.cilium, terraform_data.k3s_ready]
}
