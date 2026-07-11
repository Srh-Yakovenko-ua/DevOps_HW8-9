variable "ecr_name" {
  description = "Name of the ECR repository"
  type        = string
}

variable "scan_on_push" {
  description = "Scan images for vulnerabilities automatically on push"
  type        = bool
  default     = true
}

variable "image_tag_mutability" {
  description = "Tag mutability for the repository (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be either MUTABLE or IMMUTABLE."
  }
}

variable "max_image_count" {
  description = "Number of most recent images to keep in the repository"
  type        = number
  default     = 10
}

variable "force_delete" {
  description = "Allow the repository to be deleted while it still holds images"
  type        = bool
  default     = true
}
