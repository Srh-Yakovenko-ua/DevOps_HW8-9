# Terraform and provider version constraints for the whole project.
#
#   * aws        - all cloud infrastructure (VPC, ECR, EKS, IAM, S3/DynamoDB).
#     Pinned >= 5.40 because the EKS module uses the access_config block
#     (authentication_mode / cluster creator admin) added in that release.
#   * kubernetes - the gp3 StorageClass and the namespaces created in-cluster.
#   * helm       - installs metrics-server, Jenkins and Argo CD from their charts.
#     Pinned to the 2.x line: its provider config uses the nested `kubernetes {}`
#     block, which 3.x replaced.
#   * tls        - reads the EKS OIDC issuer thumbprint for the IRSA provider.
terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40, < 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.30, < 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12, < 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
  }
}
