variable "vpc_name" {
  description = "Name tag applied to the VPC and its resources"
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr_block, 0))
    error_message = "vpc_cidr_block must be a valid CIDR block, for example 10.0.0.0/16."
  }
}

variable "public_subnets" {
  description = "List of CIDR blocks for the public subnets"
  type        = list(string)
}

variable "private_subnets" {
  description = "List of CIDR blocks for the private subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "List of availability zones for the subnets"
  type        = list(string)
}

# Name of the EKS cluster that shares this VPC. When set, the subnets are
# tagged so Kubernetes can auto-discover them when it provisions Elastic Load
# Balancers for LoadBalancer type Services. Left empty the VPC stays a plain,
# cluster agnostic network.
variable "cluster_name" {
  description = "EKS cluster name used to tag subnets for load balancer discovery. Empty disables the tags."
  type        = string
  default     = ""
}
