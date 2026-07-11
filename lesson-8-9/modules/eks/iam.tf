# IAM roles that the EKS control plane and the worker nodes assume.
# The partition is read from the caller so the ARNs also work in GovCloud or
# China regions, not only the standard "aws" partition.
data "aws_partition" "current" {}

# ---------------------------------------------------------------------------
# Control plane role
# ---------------------------------------------------------------------------
# The EKS service assumes this role to manage AWS resources on the cluster's
# behalf (ENIs, security groups, load balancers ...).
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "eks.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = { Name = "${var.cluster_name}-cluster-role" }
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ---------------------------------------------------------------------------
# Worker node role
# ---------------------------------------------------------------------------
# The EC2 worker instances assume this role. It carries the three AWS managed
# policies every EKS node needs: the node policy, the VPC CNI policy and
# read only access to ECR so the kubelet can pull the Django image.
resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = { Name = "${var.cluster_name}-node-role" }
}

# Core permissions for a managed worker node (kubelet, etc.).
resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# Permissions the Amazon VPC CNI plugin needs to wire pod networking.
resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# Lets the kubelet pull images from ECR (our Django image) without an
# imagePullSecret.
resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
