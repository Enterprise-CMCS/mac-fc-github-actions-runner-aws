variable "container_name" {
  type        = string
  description = "Container name"
}

variable "allowed_read_principals" {
  type        = list
  description = "External principals that are allowed to read from the ECR repository"
}

variable "ci_user_arn" {
  type        = string
  description = "ARN for CI user which has read/write permissions"
}

variable "lifecycle_policy" {
  type        = string
  description = "ECR repository lifecycle policy document. Used to override the default policy."
  default     = ""
}

variable "tags" {
  type        = map(any)
  description = "Additional tags to apply."
  default     = {}
}

variable "scan_on_push" {
  type        = bool
  description = "Scan image on push to repo."
  default     = true
}
