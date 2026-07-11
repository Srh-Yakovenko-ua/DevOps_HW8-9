output "bucket_name" {
  description = "Name of the S3 bucket that stores the Terraform state"
  value       = aws_s3_bucket.state.id
}

output "bucket_arn" {
  description = "ARN of the state S3 bucket"
  value       = aws_s3_bucket.state.arn
}

output "bucket_domain_name" {
  description = "URL (domain name) of the state S3 bucket"
  value       = aws_s3_bucket.state.bucket_domain_name
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table used for state locking"
  value       = aws_dynamodb_table.locks.name
}
