# CloudStack provider reads credentials from environment variables:
#   CLOUDSTACK_API_URL
#   CLOUDSTACK_API_KEY
#   CLOUDSTACK_SECRET_KEY
provider "cloudstack" {}

provider "helm" {
  kubernetes = {
    config_path = module.cluster.kubeconfig_path
  }
}

# AWS provider reads credentials from environment variables:
#   AWS_ACCESS_KEY_ID
#   AWS_SECRET_ACCESS_KEY
#   AWS_REGION (optional, defaults to us-east-2 below)
provider "aws" {
  region = "us-east-2"
}
