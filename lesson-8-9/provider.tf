# Provider configuration shared by all modules.

# ---------------------------------------------------------------------------
# AWS
# ---------------------------------------------------------------------------
provider "aws" {
  region = var.aws_region

  # Tags applied automatically to every taggable resource.
  default_tags {
    tags = local.common_tags
  }
}

# ---------------------------------------------------------------------------
# Kubernetes / Helm
# ---------------------------------------------------------------------------
# Both providers talk to the EKS cluster created by this same configuration.
# They authenticate with the AWS CLI exec plugin, which mints a short-lived
# token at apply time, so no kubeconfig file is written and no credential is
# stored in the Terraform state. The endpoint and CA come from the eks module.
#
# On the very FIRST apply these values are unknown until the cluster exists,
# which is why the bootstrap flow brings the cluster up first (`make infra`,
# then `make platform`). On every later apply the values are already known and
# a plain `terraform apply` reconciles everything in one shot. See README.
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
    }
  }
}
