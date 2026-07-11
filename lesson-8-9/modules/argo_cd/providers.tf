# Providers this module needs. Configuration is passed in from the root module
# (the same Kubernetes + Helm providers used by the Jenkins module), so both
# platform tools install into the one EKS cluster.
terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}
