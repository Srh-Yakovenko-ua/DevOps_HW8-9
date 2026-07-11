# EKS cluster (control plane) plus a managed node group and the core add-ons.
# The cluster is created inside the existing VPC: the control plane ENIs live
# in the supplied subnets and the worker nodes run in the private subnets.

# ---------------------------------------------------------------------------
# Control plane
# ---------------------------------------------------------------------------
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    # Control plane ENIs are spread across all supplied subnets so the API
    # server is reachable from every AZ.
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
  }

  # API authentication mode with the cluster creator granted admin rights, so
  # whoever runs `terraform apply` can immediately use kubectl. This is the
  # modern replacement for hand editing the aws-auth ConfigMap.
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  # Send control plane logs to CloudWatch for troubleshooting.
  enabled_cluster_log_types = var.cluster_log_types

  tags = { Name = var.cluster_name }

  # The cluster cannot be created before its role has the required policy.
  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
}

# ---------------------------------------------------------------------------
# Managed node group
# ---------------------------------------------------------------------------
# The worker nodes that actually run the Django pods. They live in the private
# subnets and reach the internet (to pull images, talk to the API) through the
# VPC's NAT Gateway.
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-ng"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.node_subnet_ids

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  # Roll nodes one at a time on updates so the app stays available.
  update_config {
    max_unavailable = 1
  }

  instance_types = var.node_instance_types
  capacity_type  = var.node_capacity_type
  ami_type       = var.node_ami_type
  disk_size      = var.node_disk_size

  labels = {
    role = "app"
  }

  tags = { Name = "${var.cluster_name}-ng" }

  # Node group needs the node role's policies attached first.
  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_ecr,
  ]

  # Terraform tries to keep desired_size in sync, but once the Horizontal Pod
  # Autoscaler / Cluster Autoscaler changes the node count we do not want a
  # later apply to reset it.
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# ---------------------------------------------------------------------------
# Core add-ons
# ---------------------------------------------------------------------------
# Managed versions of the components every cluster needs. Letting EKS manage
# them keeps them patched and compatible with the control plane version.

# Pod networking.
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.this]
}

# In-cluster DNS.
resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # CoreDNS runs as pods, so it needs the node group to exist first.
  depends_on = [aws_eks_node_group.this]
}

# Service networking (kube-proxy).
resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.this]
}
