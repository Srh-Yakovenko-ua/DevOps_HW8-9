# Current AWS account and partition, used to scope the repository access policy.
# Reading the partition keeps the ARN valid outside standard AWS too (GovCloud,
# China), not only in the default "aws" partition.
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# ECR repository for Docker images.
resource "aws_ecr_repository" "this" {
  name                 = var.ecr_name
  image_tag_mutability = var.image_tag_mutability

  # Allow the repository to be destroyed even when it still holds images.
  force_delete = var.force_delete

  # Scan images for known vulnerabilities on every push.
  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  # Encrypt images at rest.
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = var.ecr_name
  }
}

# Access policy: allow the owning AWS account to push and pull images.
resource "aws_ecr_repository_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAccountPushPull"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
      }
    ]
  })
}

# Lifecycle policy: keep only the most recent images to control storage cost.
resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the most recent images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.max_image_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
