# Cluster-wide platform pieces that sit between the raw EKS cluster and the
# CI/CD tooling. Both need the Kubernetes/Helm providers, so they live at the
# root (where those providers are configured) rather than inside the eks module.

# ---------------------------------------------------------------------------
# Default StorageClass (gp3)
# ---------------------------------------------------------------------------
# EKS ships no default StorageClass once you use the EBS CSI driver, so a PVC
# (e.g. Jenkins' JENKINS_HOME) would stay Pending. This marks gp3 as the default
# and provisions encrypted volumes through the driver installed by the eks module.
resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  parameters = {
    type      = "gp3"
    encrypted = "true"
  }

  depends_on = [module.eks]
}

# ---------------------------------------------------------------------------
# metrics-server
# ---------------------------------------------------------------------------
# Supplies the CPU/memory metrics the django-app HorizontalPodAutoscaler reads.
# EKS does not bundle it.
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.metrics_server_chart_version != "" ? var.metrics_server_chart_version : null
  namespace  = "kube-system"

  # Avoid the occasional kubelet serving-cert SAN mismatch on EKS.
  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }

  depends_on = [module.eks]
}
