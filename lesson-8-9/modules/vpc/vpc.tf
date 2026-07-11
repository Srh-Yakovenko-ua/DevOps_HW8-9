# Main VPC.
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name
  }
}

# Tag added to every subnet when the VPC is shared with an EKS cluster. It
# marks the subnets as belonging to the cluster so the AWS cloud controller can
# discover them. Empty (no cluster_name) yields no extra tag.
locals {
  cluster_tag = var.cluster_name != "" ? {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  } : {}
}

# Public subnets, one per availability zone. Instances launched here get a
# public IP automatically. The kubernetes.io/role/elb tag lets EKS place
# internet facing load balancers in these subnets.
resource "aws_subnet" "public" {
  count                   = length(var.public_subnets)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.cluster_tag, {
    Name                     = "${var.vpc_name}-public-${count.index + 1}"
    Tier                     = "public"
    "kubernetes.io/role/elb" = "1"
  })
}

# Private subnets, one per availability zone. The kubernetes.io/role/internal-elb
# tag lets EKS place internal load balancers and worker nodes here.
resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(local.cluster_tag, {
    Name                              = "${var.vpc_name}-private-${count.index + 1}"
    Tier                              = "private"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# Internet Gateway that gives the public subnets access to the internet.
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

# Elastic IP for the NAT Gateway.
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.vpc_name}-nat-eip"
  }

  depends_on = [aws_internet_gateway.this]
}

# Single NAT Gateway placed in the first public subnet. It lets instances in
# the private subnets reach the internet for outbound traffic only.
# A production setup would use one NAT Gateway per AZ for high availability.
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.vpc_name}-nat"
  }

  depends_on = [aws_internet_gateway.this]
}
