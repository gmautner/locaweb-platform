provider "cloudstack" {
  api_url    = var.cloudstack_api_url
  api_key    = var.cloudstack_api_key
  secret_key = var.cloudstack_secret_key
}

provider "helm" {
  kubernetes = {
    config_path = module.cluster.kubeconfig_path
  }
}
