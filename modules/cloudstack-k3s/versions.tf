terraform {
  required_version = "~> 1.6.0"

  required_providers {
    cloudstack = {
      source  = "cloudstack/cloudstack"
      version = "~> 0.5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5.0"
    }
  }
}

