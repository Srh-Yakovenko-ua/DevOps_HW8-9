variable "bucket_name" {
  description = "Name of the S3 bucket that stores Terraform state files"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be 3 to 63 characters and use only lowercase letters, numbers, dots or hyphens."
  }
}

variable "table_name" {
  description = "Name of the DynamoDB table used for state locking"
  type        = string
  default     = "terraform-locks"
}

variable "force_destroy" {
  description = "Allow the bucket to be destroyed while it still holds objects"
  type        = bool
  default     = true
}
