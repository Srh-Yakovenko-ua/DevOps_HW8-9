# ---------------------------------------------------------------------------
# Release / placement
# ---------------------------------------------------------------------------
variable "release_name" {
  description = "Helm release name for Jenkins (also the controller Service name)"
  type        = string
  default     = "jenkins"
}

variable "namespace" {
  description = "Namespace Jenkins (controller + build agents) runs in"
  type        = string
  default     = "jenkins"
}

variable "chart_version" {
  description = "Version of the jenkins/jenkins Helm chart"
  type        = string
}

variable "service_type" {
  description = "Kubernetes Service type for the Jenkins UI (LoadBalancer, NodePort or ClusterIP)"
  type        = string
  default     = "LoadBalancer"
}

variable "storage_class" {
  description = "StorageClass used for the JENKINS_HOME PersistentVolumeClaim"
  type        = string
}

variable "persistence_size" {
  description = "Size of the JENKINS_HOME persistent volume"
  type        = string
  default     = "8Gi"
}

variable "agent_service_account_name" {
  description = "Name of the Kubernetes ServiceAccount the build agents run under (IRSA enabled for ECR push)"
  type        = string
  default     = "jenkins-agent"
}

# ---------------------------------------------------------------------------
# AWS / IRSA
# ---------------------------------------------------------------------------
variable "aws_region" {
  description = "AWS region (exposed to the pipeline as $AWS_REGION)"
  type        = string
}

variable "account_id" {
  description = "AWS account id (exposed to the pipeline as $AWS_ACCOUNT_ID)"
  type        = string
}

variable "ecr_repository_url" {
  description = "ECR repository URL the pipeline pushes the image to"
  type        = string
}

variable "ecr_repository_arn" {
  description = "ECR repository ARN the agent IRSA role is allowed to push/pull"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the cluster IAM OIDC provider (for the agent IRSA role)"
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC issuer host/path without scheme (for the IRSA trust condition)"
  type        = string
}

# ---------------------------------------------------------------------------
# Pipeline / GitOps
# ---------------------------------------------------------------------------
variable "job_name" {
  description = "Name of the pipeline job created via JCasC seed"
  type        = string
  default     = "dealsbe-cicd"
}

variable "git_repo_url" {
  description = "HTTPS URL of the Git repo holding the Jenkinsfile and the Helm chart"
  type        = string
}

variable "gitops_branch" {
  description = "Branch the pipeline checks out and pushes the values bump to"
  type        = string
  default     = "main"
}

variable "jenkinsfile_path" {
  description = "Path of the Jenkinsfile inside the repo (scriptPath for the seed job)"
  type        = string
  default     = "Jenkinsfile"
}

variable "values_path" {
  description = "Path of the Helm values.yaml the pipeline bumps (relative to repo root)"
  type        = string
  default     = "charts/django-app/values.yaml"
}

variable "app_context_path" {
  description = "Path of the Docker build context (the Django app) relative to repo root"
  type        = string
  default     = "app"
}

# ---------------------------------------------------------------------------
# Credentials
# ---------------------------------------------------------------------------
variable "github_credentials_id" {
  description = "Jenkins credentials id used by the pipeline to push to Git"
  type        = string
  default     = "github-credentials"
}

variable "github_username" {
  description = "GitHub username the pipeline commits/pushes as"
  type        = string
  default     = ""
}

variable "github_token" {
  description = "GitHub Personal Access Token (repo scope) used to push the values bump"
  type        = string
  default     = ""
  sensitive   = true
}

variable "admin_user" {
  description = "Jenkins admin username"
  type        = string
  default     = "admin"
}

variable "admin_password" {
  description = "Jenkins admin password. Leave empty to let the chart generate a random one (retrieved from the jenkins secret)."
  type        = string
  default     = ""
  sensitive   = true
}
