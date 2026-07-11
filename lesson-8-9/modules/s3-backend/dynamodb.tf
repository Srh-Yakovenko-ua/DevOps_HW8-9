# DynamoDB table used by the S3 backend to lock the state during operations.
# The LockID attribute is required by Terraform for the locking mechanism.
resource "aws_dynamodb_table" "locks" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = var.table_name
  }
}
