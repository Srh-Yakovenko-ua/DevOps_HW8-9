# Amazon EBS CSI driver.
#
# Lets Kubernetes dynamically provision EBS volumes for PersistentVolumeClaims.
# Jenkins keeps its state (JENKINS_HOME) on a PVC, so without this add-on the
# Jenkins pod would stay Pending forever waiting for a volume. The driver is
# installed as a managed EKS add-on and authenticated with IRSA, so it needs no
# credentials on the nodes.

# IAM role the EBS CSI controller service account assumes through IRSA.
resource "aws_iam_role" "ebs_csi" {
  name = "${var.cluster_name}-ebs-csi-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.this.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          "${local.oidc_provider}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = { Name = "${var.cluster_name}-ebs-csi-role" }
}

# AWS managed policy with exactly the permissions the driver needs.
resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# The managed add-on. service_account_role_arn binds the driver's service
# account (kube-system/ebs-csi-controller-sa) to the IRSA role above.
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = aws_eks_cluster.this.name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi.arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # The controller runs as pods, so the node group must exist, and the IAM
  # policy must be attached before the driver starts using the role.
  depends_on = [
    aws_eks_node_group.this,
    aws_iam_role_policy_attachment.ebs_csi,
  ]

  tags = { Name = "${var.cluster_name}-ebs-csi" }
}
