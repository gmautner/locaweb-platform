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
