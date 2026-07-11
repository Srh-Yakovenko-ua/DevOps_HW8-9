# Jenkins installed via the official Helm chart and configured entirely as code
# (JCasC): the Kubernetes agent cloud, the GitHub credential and the pipeline
# job are all created on startup, so a fresh install is immediately usable with
# no clicking in the UI.

# Namespace for the controller and the ephemeral build agents.
resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/part-of" = "dealsbe-cicd"
    }
  }
}

# ---------------------------------------------------------------------------
# IRSA role for the build agents (Kaniko -> ECR push)
# ---------------------------------------------------------------------------
# The agent pods run under the "jenkins-agent" ServiceAccount. Annotating that
# SA with this role's ARN lets Kaniko obtain ECR credentials through a web
# identity token - no Docker credentials, no long-lived keys.
resource "aws_iam_role" "agent" {
  name = "${var.release_name}-agent-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_provider_url}:sub" = "system:serviceaccount:${var.namespace}:${var.agent_service_account_name}"
          "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = { Name = "${var.release_name}-agent-ecr-role" }
}

# GetAuthorizationToken must be granted on "*" (it is account-wide); the actual
# push/pull actions are scoped to the one Dealsbe repository.
resource "aws_iam_role_policy" "agent_ecr" {
  name = "${var.release_name}-agent-ecr-policy"
  role = aws_iam_role.agent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EcrAuthToken"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "EcrPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = var.ecr_repository_arn
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# GitHub credential (consumed by JCasC and injected as $GITHUB_TOKEN)
# ---------------------------------------------------------------------------
# The token lives in a Kubernetes Secret and is mounted into the controller as
# environment variables. JCasC references ${GITHUB_USERNAME} / ${GITHUB_TOKEN}
# so the raw token never appears in the rendered Helm values.
resource "kubernetes_secret" "github" {
  metadata {
    name      = "github-credentials"
    namespace = kubernetes_namespace.this.metadata[0].name
  }
  type = "Opaque"
  data = {
    username = var.github_username
    token    = var.github_token
  }
}

# ---------------------------------------------------------------------------
# Helm release
# ---------------------------------------------------------------------------
resource "helm_release" "jenkins" {
  name       = var.release_name
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  version    = var.chart_version
  namespace  = kubernetes_namespace.this.metadata[0].name

  # Plugin download + controller boot can take a few minutes on a fresh cluster.
  timeout = 900
  wait    = true

  values = [templatefile("${path.module}/values.yaml", {
    service_type               = var.service_type
    storage_class              = var.storage_class
    persistence_size           = var.persistence_size
    namespace                  = var.namespace
    agent_service_account_name = var.agent_service_account_name
    agent_role_arn             = aws_iam_role.agent.arn
    admin_user                 = var.admin_user
    github_secret_name         = kubernetes_secret.github.metadata[0].name
    github_credentials_id      = var.github_credentials_id
    job_name                   = var.job_name
    git_repo_url               = var.git_repo_url
    gitops_branch              = var.gitops_branch
    jenkinsfile_path           = var.jenkinsfile_path
    values_path                = var.values_path
    app_context_path           = var.app_context_path
    ecr_repository_url         = var.ecr_repository_url
    aws_region                 = var.aws_region
    account_id                 = var.account_id
  })]

  # Only pin the admin password when the caller supplied one; otherwise the
  # chart generates a random password (read it from the "jenkins" secret).
  dynamic "set_sensitive" {
    for_each = var.admin_password != "" ? [1] : []
    content {
      name  = "controller.admin.password"
      value = var.admin_password
    }
  }

  depends_on = [
    kubernetes_secret.github,
    aws_iam_role_policy.agent_ecr,
  ]
}
