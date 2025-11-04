variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "github_owner" {
  description = "GitHub organization or username"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository name"
  type        = string
}

variable "project_name" {
  description = "Project name (lowercase, alphanumeric, hyphens only)"
  type        = string
  default     = "test-runner"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "compute_type" {
  description = "CodeBuild compute type"
  type        = string
  default     = "BUILD_GENERAL1_SMALL"
}

variable "concurrent_build_limit" {
  description = "Maximum concurrent builds"
  type        = number
  default     = 5
}

variable "skip_webhook_creation" {
  description = "Skip webhook creation (set to true on first apply, false on second)"
  type        = bool
  default     = false
}

variable "github_connection_name" {
  description = "Name for AWS CodeConnections connection (module creates it, then authorize in AWS console)"
  type        = string
  default     = "github-runner-connection"
}
