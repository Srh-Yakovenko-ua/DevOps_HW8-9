# ---------------------------------------------------------------------------
# Global
# ---------------------------------------------------------------------------
variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-west-2"
}

variable "project" {
  description = "Project name, used as a resource name prefix and in tags"
  type        = string
  default     = "lesson-8-9"
}

# ---------------------------------------------------------------------------
# Remote state backend
# ---------------------------------------------------------------------------
variable "state_bucket_name" {
  description = "S3 bucket for the Terraform state. Leave empty to derive a globally unique name from the account id."
  type        = string
  default     = ""
}

variable "lock_table_name" {
  description = "DynamoDB table name for state locking"
  type        = string
  default     = "terraform-locks"
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------
variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets, one per availability zone"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets, one per availability zone"
  type        = list(string)
  default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

# ---------------------------------------------------------------------------
# ECR
# ---------------------------------------------------------------------------
variable "ecr_scan_on_push" {
  description = "Scan images for vulnerabilities on push"
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# EKS
# ---------------------------------------------------------------------------
variable "kubernetes_version" {
  description = "Kubernetes control plane version for the EKS cluster"
  type        = string
  default     = "1.31"
}

variable "node_instance_types" {
  description = "EC2 instance types for the EKS worker nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired number of EKS worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of EKS worker nodes"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of EKS worker nodes"
  type        = number
  default     = 4
}

# ---------------------------------------------------------------------------
# GitOps repository (the one Jenkins pushes to and Argo CD tracks)
# ---------------------------------------------------------------------------
# REQUIRED. The HTTPS URL of the Git repo that holds this project (Jenkinsfile,
# charts/, app/). Jenkins bumps charts/django-app/values.yaml here and Argo CD
# reconciles the cluster from it. Example:
#   https://github.com/<you>/DevOps_HW8-9.git
variable "git_repo_url" {
  description = "HTTPS URL of the Git repo Jenkins pushes to and Argo CD tracks"
  type        = string
}

variable "gitops_branch" {
  description = "Branch the pipeline pushes to and Argo CD syncs from"
  type        = string
  default     = "main"
}

# Path of THIS project inside the repo. If the repo root IS the project (this
# folder's contents at the repo root) set it to "". If the whole DevOps_HW8-9
# folder is the repo, the project lives under "lesson-8-9" (the default).
variable "repo_path_prefix" {
  description = "Subdirectory of the project inside the Git repo (\"\" if the project is the repo root)"
  type        = string
  default     = "lesson-8-9"
}

# ---------------------------------------------------------------------------
# GitHub credentials (used by Jenkins to push; optionally by Argo CD for a
# private repo). Prefer passing the token via the TF_VAR_github_token env var.
# ---------------------------------------------------------------------------
variable "github_username" {
  description = "GitHub username used by the pipeline to push the values bump"
  type        = string
  default     = ""
}

variable "github_token" {
  description = "GitHub Personal Access Token (repo scope). Set via TF_VAR_github_token."
  type        = string
  default     = ""
  sensitive   = true
}

variable "repo_private" {
  description = "Set true if the Git repo is private (Argo CD then gets a repository credential)"
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Jenkins
# ---------------------------------------------------------------------------
variable "jenkins_namespace" {
  description = "Namespace Jenkins runs in"
  type        = string
  default     = "jenkins"
}

variable "jenkins_chart_version" {
  description = "Version of the jenkins/jenkins Helm chart"
  type        = string
  default     = "5.9.33"
}

variable "jenkins_service_type" {
  description = "Service type for the Jenkins UI (LoadBalancer / NodePort / ClusterIP)"
  type        = string
  default     = "LoadBalancer"
}

variable "jenkins_admin_user" {
  description = "Jenkins admin username"
  type        = string
  default     = "admin"
}

variable "jenkins_admin_password" {
  description = "Jenkins admin password. Empty = chart generates a random one (read it from the jenkins secret)."
  type        = string
  default     = ""
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Argo CD
# ---------------------------------------------------------------------------
variable "argocd_namespace" {
  description = "Namespace Argo CD runs in"
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "Version of the argo/argo-cd Helm chart"
  type        = string
  default     = "10.1.3"
}

variable "argocd_service_type" {
  description = "Service type for the Argo CD server UI/API"
  type        = string
  default     = "LoadBalancer"
}

variable "app_namespace" {
  description = "Namespace the Dealsbe application is deployed into by Argo CD"
  type        = string
  default     = "dealsbe"
}

# ---------------------------------------------------------------------------
# Cluster platform add-ons
# ---------------------------------------------------------------------------
variable "metrics_server_chart_version" {
  description = "Version of the metrics-server Helm chart. Empty installs the latest."
  type        = string
  default     = ""
}
