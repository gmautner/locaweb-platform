module "cluster" {
  source = "../modules/cloudstack-k3s"

  cluster_name          = var.cluster_name
  cloudstack_api_key    = var.cloudstack_api_key
  cloudstack_secret_key = var.cloudstack_secret_key
  k3s_version           = var.k3s_version

  options  = var.options
  advanced = var.advanced
}
