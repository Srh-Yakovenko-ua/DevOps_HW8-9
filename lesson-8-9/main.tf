# Root module: wires the S3 backend, VPC, ECR, EKS, Jenkins and Argo CD modules.
# The infrastructure modules (s3-backend, vpc, ecr, eks) have sensible defaults;
# the platform modules (jenkins, argo_cd) only require git_repo_url. See README
# for the two-phase bootstrap that brings the cluster up before installing the
# platform tools on top of it.

# Remote state storage: S3 bucket plus a DynamoDB table for locking.
module "s3_backend" {
  source      = "./modules/s3-backend"
  bucket_name = local.state_bucket_name
  table_name  = var.lock_table_name
}

# Network layer: VPC with public and private subnets across the region AZs.
# The cluster name is passed so the subnets get tagged for EKS load balancer
# discovery. This is the same VPC the EKS cluster below runs in.
module "vpc" {
  source             = "./modules/vpc"
  vpc_name           = "${var.project}-vpc"
  vpc_cidr_block     = var.vpc_cidr_block
  public_subnets     = var.public_subnet_cidrs
  private_subnets    = var.private_subnet_cidrs
  availability_zones = local.azs
  cluster_name       = local.cluster_name
}

# Container registry for the Django Docker image.
module "ecr" {
  source       = "./modules/ecr"
  ecr_name     = "${var.project}-ecr"
  scan_on_push = var.ecr_scan_on_push
}

# Kubernetes cluster (EKS) running inside the VPC above. The control plane
# spans every subnet; the worker nodes run in the private subnets and reach
# the internet through the VPC's NAT Gateway.
module "eks" {
  source     = "./modules/eks"
  aws_region = var.aws_region

  cluster_name       = local.cluster_name
  kubernetes_version = var.kubernetes_version

  subnet_ids      = concat(module.vpc.public_subnet_ids, module.vpc.private_subnet_ids)
  node_subnet_ids = module.vpc.private_subnet_ids

  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
}

# ---------------------------------------------------------------------------
# CI: Jenkins (build + push to ECR + bump Git)
# ---------------------------------------------------------------------------
# Installed with Helm, configured as code. Its build agents assume an IRSA role
# to push images to the ECR repository above. The pipeline it creates pushes a
# values bump back to Git, which Argo CD (below) then reconciles.
module "jenkins" {
  source = "./modules/jenkins"
  providers = {
    aws        = aws
    helm       = helm
    kubernetes = kubernetes
  }

  namespace     = var.jenkins_namespace
  chart_version = var.jenkins_chart_version
  service_type  = var.jenkins_service_type
  storage_class = kubernetes_storage_class.gp3.metadata[0].name

  aws_region         = var.aws_region
  account_id         = data.aws_caller_identity.current.account_id
  ecr_repository_url = module.ecr.repository_url
  ecr_repository_arn = module.ecr.repository_arn
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_provider_url  = module.eks.oidc_provider_url

  git_repo_url     = var.git_repo_url
  gitops_branch    = var.gitops_branch
  jenkinsfile_path = local.gitops_jenkinsfile
  values_path      = local.gitops_values_path
  app_context_path = local.gitops_app_context

  github_username = var.github_username
  github_token    = var.github_token
  admin_user      = var.jenkins_admin_user
  admin_password  = var.jenkins_admin_password

  depends_on = [module.eks, kubernetes_storage_class.gp3]
}

# ---------------------------------------------------------------------------
# CD: Argo CD (GitOps sync of the Dealsbe chart)
# ---------------------------------------------------------------------------
module "argo_cd" {
  source = "./modules/argo_cd"
  providers = {
    helm       = helm
    kubernetes = kubernetes
  }

  namespace           = var.argocd_namespace
  chart_version       = var.argocd_chart_version
  server_service_type = var.argocd_service_type

  git_repo_url       = var.git_repo_url
  gitops_branch      = var.gitops_branch
  argo_chart_path    = local.gitops_chart_path
  app_namespace      = var.app_namespace
  ecr_repository_url = module.ecr.repository_url

  repo_private    = var.repo_private
  github_username = var.github_username
  github_token    = var.github_token

  depends_on = [module.eks]
}
