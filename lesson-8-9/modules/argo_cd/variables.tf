# ---------------------------------------------------------------------------
# Release / placement
# ---------------------------------------------------------------------------
variable "release_name" {
  description = "Helm release name for Argo CD"
  type        = string
  default     = "argocd"
}

variable "apps_release_name" {
  description = "Helm release name for the app-of-apps chart"
  type        = string
  default     = "dealsbe-apps"
}

variable "namespace" {
  description = "Namespace Argo CD runs in"
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "Version of the argo/argo-cd Helm chart"
  type        = string
}

variable "server_service_type" {
  description = "Kubernetes Service type for the Argo CD server UI/API"
  type        = string
  default     = "LoadBalancer"
}

# ---------------------------------------------------------------------------
# Application (what Argo CD watches and deploys)
# ---------------------------------------------------------------------------
variable "app_name" {
  description = "Name of the Argo CD Application"
  type        = string
  default     = "dealsbe"
}

variable "app_project" {
  description = "Argo CD project the Application belongs to"
  type        = string
  default     = "default"
}

variable "app_namespace" {
  description = "Namespace the Dealsbe app is deployed into (created on first sync)"
  type        = string
  default     = "dealsbe"
}

variable "git_repo_url" {
  description = "HTTPS URL of the Git repo Argo CD tracks"
  type        = string
}

variable "gitops_branch" {
  description = "Branch/revision Argo CD tracks"
  type        = string
  default     = "main"
}

variable "argo_chart_path" {
  description = "Path to the django-app Helm chart inside the repo"
  type        = string
  default     = "charts/django-app"
}

variable "ecr_repository_url" {
  description = "ECR repository URL, injected as the chart's image.repository so values.yaml only needs to carry the tag"
  type        = string
}

# ---------------------------------------------------------------------------
# Optional private-repo credentials
# ---------------------------------------------------------------------------
variable "repo_private" {
  description = "Set true if the Git repo is private, so Argo CD gets a repository credential Secret"
  type        = bool
  default     = false
}

variable "github_username" {
  description = "GitHub username for the Argo CD repository credential (private repos only)"
  type        = string
  default     = ""
}

variable "github_token" {
  description = "GitHub token for the Argo CD repository credential (private repos only)"
  type        = string
  default     = ""
  sensitive   = true
}
