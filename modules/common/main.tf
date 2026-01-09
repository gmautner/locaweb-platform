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
    var.ingress_ip_address != "" ? {
      service = {
        type = "LoadBalancer"
        spec = {
          loadBalancerIP = var.ingress_ip_address
        }
      }
    } : {}
  )
}

resource "helm_release" "traefik" {
  name       = "traefik"
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = "~> 38.0.1"
  namespace  = "traefik"

  create_namespace = true

  values = [yamlencode(local.traefik_values)]
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "~> 1.19.2"
  namespace  = "cert-manager"

  create_namespace = true

  values = [
    yamlencode({
      installCRDs = true
    })
  ]
}

resource "helm_release" "cert_manager_issuers" {
  name      = "cert-manager-issuers"
  chart     = "${var.charts_path}/cert-manager-issuers"
  namespace = "cert-manager"

  create_namespace = false

  values = [
    yamlencode({
      email                = var.cert_manager_email
      server               = var.cert_manager_acme_server
      privateKeySecretName = var.cert_manager_private_key_secret_name
      ingressClassName     = var.ingress_class_name
    })
  ]

  depends_on = [helm_release.cert_manager]
}

resource "helm_release" "k8up" {
  name       = "k8up"
  repository = "https://k8up-io.github.io/k8up"
  chart      = "k8up"
  version    = "~> 4.8.6"
  namespace  = "k8up"

  create_namespace = true

  values = [
    yamlencode({
      k8up = {
        timezone = var.k8up_timezone
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
}

