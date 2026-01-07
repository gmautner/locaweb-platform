module "cluster" {
  source = "../modules/cloudstack-k3s"

  cluster_prefix        = var.cluster_prefix
  cloudstack_api_key    = var.cloudstack_api_key
  cloudstack_secret_key = var.cloudstack_secret_key
  k3s_version           = var.k3s_version
  base_domain           = var.base_domain

  options  = var.options
  advanced = var.advanced
}
