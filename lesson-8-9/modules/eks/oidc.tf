# OIDC identity provider for the cluster.
#
# Registering the cluster's OIDC issuer with IAM enables IRSA (IAM Roles for
# Service Accounts): a Kubernetes service account can assume an IAM role through
# a signed web identity token, so pods get scoped AWS permissions without any
# static credentials on the nodes. Two things in this project rely on it:
#   * the EBS CSI driver controller  (aws_ebs_csi_driver.tf)
#   * the Jenkins Kaniko build agent  (modules/jenkins) that pushes to ECR
data "tls_certificate" "oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]

  tags = { Name = "${var.cluster_name}-oidc" }
}

locals {
  # OIDC issuer host+path without the "https://" scheme. Used to build the IRSA
  # trust-policy condition keys "<issuer>:sub" and "<issuer>:aud".
  oidc_provider = replace(aws_iam_openid_connect_provider.this.url, "https://", "")
}
