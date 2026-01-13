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
