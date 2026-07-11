variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "aws_region" {
  description = "AWS region the cluster runs in (used to build the kubeconfig helper command)"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes control plane version"
  type        = string
  default     = "1.31"
}

variable "subnet_ids" {
  description = "Subnet IDs for the control plane ENIs (usually all public and private subnets)"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "EKS requires subnets in at least two availability zones."
  }
}

variable "node_subnet_ids" {
  description = "Subnet IDs where the worker nodes run (private subnets are recommended)"
  type        = list(string)

  validation {
    condition     = length(var.node_subnet_ids) >= 1
    error_message = "At least one subnet is required for the node group."
  }
}

# --- Node group sizing ------------------------------------------------------

variable "node_instance_types" {
  description = "EC2 instance types for the worker nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of worker nodes (headroom for the HPA to scale pods onto)"
  type        = number
  default     = 4
}

variable "node_disk_size" {
  description = "EBS root volume size for each node, in GiB"
  type        = number
  default     = 20
}

variable "node_capacity_type" {
  description = "Node capacity type: ON_DEMAND or SPOT"
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "node_ami_type" {
  description = "AMI type for the managed node group (for example AL2023_x86_64_STANDARD or AL2023_ARM_64_STANDARD)"
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

# --- API endpoint access ----------------------------------------------------

variable "endpoint_public_access" {
  description = "Expose the Kubernetes API server endpoint publicly (needed for kubectl from your laptop)"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public API endpoint. Narrow this to your IP in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_log_types" {
  description = "Control plane log types to ship to CloudWatch"
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}
