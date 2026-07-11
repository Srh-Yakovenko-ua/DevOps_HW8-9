# Current region availability zones and the caller AWS account.
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

locals {
  # Global tags applied to every resource through the provider default_tags.
  common_tags = {
    Project   = var.project
    ManagedBy = "Terraform"
  }

  # Pick as many AZs as there are subnets, straight from the current region,
  # so the project is not tied to hardcoded zone names.
  azs = slice(data.aws_availability_zones.available.names, 0, length(var.public_subnet_cidrs))

  # When state_bucket_name is left empty, build a globally unique name from the
  # project and the current AWS account id. This lets any account deploy the
  # project without editing the code.
  state_bucket_name = var.state_bucket_name != "" ? var.state_bucket_name : "${var.project}-tfstate-${data.aws_caller_identity.current.account_id}"

  # Static cluster name derived from the project. Computed here so it can be
  # passed to both the VPC module (for subnet tags) and the EKS module without
  # creating a dependency cycle.
  cluster_name = "${var.project}-eks"

  # In-repo paths. When the project sits in a subdirectory of the Git repo
  # (repo_path_prefix, e.g. "lesson-8-9"), every path Jenkins and Argo CD use
  # must be prefixed with it. An empty prefix means the project is the repo root.
  repo_prefix        = var.repo_path_prefix == "" ? "" : "${trimsuffix(var.repo_path_prefix, "/")}/"
  gitops_values_path = "${local.repo_prefix}charts/django-app/values.yaml"
  gitops_chart_path  = "${local.repo_prefix}charts/django-app"
  gitops_jenkinsfile = "${local.repo_prefix}Jenkinsfile"
  gitops_app_context = "${local.repo_prefix}app"
}
