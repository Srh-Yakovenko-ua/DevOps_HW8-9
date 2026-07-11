# Argo CD installed via the official Helm chart, plus a small "app-of-apps"
# chart that declares the Dealsbe Application. Once installed, Argo CD watches
# the Git repo and keeps the cluster in sync with charts/django-app - no manual
# kubectl/helm after the first apply.

# Namespace for the Argo CD control plane.
resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/part-of" = "dealsbe-cicd"
    }
  }
}

# ---------------------------------------------------------------------------
# Argo CD control plane
# ---------------------------------------------------------------------------
resource "helm_release" "argocd" {
  name       = var.release_name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version
  namespace  = kubernetes_namespace.this.metadata[0].name

  timeout = 900
  wait    = true

  values = [templatefile("${path.module}/values.yaml", {
    server_service_type = var.server_service_type
  })]
}

# ---------------------------------------------------------------------------
# App-of-apps: the Argo CD Application (+ optional repo credential)
# ---------------------------------------------------------------------------
# A local Helm chart whose only job is to render the Application CRD (and, for a
# private repo, a repository Secret). It must install after the control plane so
# the argoproj.io CRDs already exist.
resource "helm_release" "apps" {
  name      = var.apps_release_name
  chart     = "${path.module}/charts"
  namespace = kubernetes_namespace.this.metadata[0].name

  values = [yamlencode({
    appName              = var.app_name
    project              = var.app_project
    repoURL              = var.git_repo_url
    targetRevision       = var.gitops_branch
    path                 = var.argo_chart_path
    destinationServer    = "https://kubernetes.default.svc"
    destinationNamespace = var.app_namespace
    imageRepository      = var.ecr_repository_url
    autoSync             = true
    repository = {
      enabled  = var.repo_private
      url      = var.git_repo_url
      username = var.github_username
    }
  })]

  # Keep the private-repo token out of the plan/values; inject it separately.
  dynamic "set_sensitive" {
    for_each = var.repo_private ? [1] : []
    content {
      name  = "repository.password"
      value = var.github_token
    }
  }

  depends_on = [helm_release.argocd]
}
