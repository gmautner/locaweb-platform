locals {
  cert_manager_acme_server             = "https://acme-v02.api.letsencrypt.org/directory"
  cert_manager_private_key_secret_name = "letsencrypt-http-prod"
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
      server               = local.cert_manager_acme_server
      privateKeySecretName = local.cert_manager_private_key_secret_name
      ingressClassName     = var.ingress_class_name
    })
  ]

  depends_on = [helm_release.cert_manager]
}
