# S3 bucket that stores Terraform state files.
resource "aws_s3_bucket" "state" {
  bucket = var.bucket_name

  # Allow the bucket to be destroyed even when it still holds state objects.
  # Handy in a learning environment where the whole stack is torn down
  # with terraform destroy.
  force_destroy = var.force_destroy

  tags = {
    Name = var.bucket_name
  }
}

# Keep a full version history of every state change.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt state at rest with server side encryption.
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block every form of public access to the state bucket.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
