variable "repository_name" {
  description = "Name of the ECR repository"
  type        = string
}

variable "image_tag_mutability" {
  description = "Whether image tags can be overwritten"
  type        = string
  default     = "IMMUTABLE"

  validation {
    condition = contains(
      ["MUTABLE", "IMMUTABLE"],
      var.image_tag_mutability
    )

    error_message = "image_tag_mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "Scan images for vulnerabilities after push"
  type        = bool
  default     = true
}

variable "force_delete" {
  description = "Allow deleting repository containing images"
  type        = bool
  default     = false
}

variable "lifecycle_policy_enabled" {
  description = "Enable automatic image cleanup"
  type        = bool
  default     = true
}

variable "untagged_images_to_keep" {
  description = "Number of untagged images to keep"
  type        = number
  default     = 1
}

variable "tagged_images_to_keep" {
  description = "Number of tagged images to keep"
  type        = number
  default     = 10
}

variable "tags" {
  description = "Tags applied to the repository"
  type        = map(string)
  default     = {}
}