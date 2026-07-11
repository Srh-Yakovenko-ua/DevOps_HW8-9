# Providers this module needs. The actual provider *configuration* lives in the
# root module (provider.tf) and is passed in with a `providers = {}` block, so
# Jenkins, Argo CD and the root all talk to the same cluster and AWS account.
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}
