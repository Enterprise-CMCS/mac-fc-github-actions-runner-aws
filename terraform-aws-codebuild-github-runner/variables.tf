# Required Variables
variable "github_owner" {
  description = "GitHub organization or user name"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository name"
  type        = string
}

variable "project_name" {
  description = "Name prefix for all resources"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

# Optional Variables
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "auth_method" {
  description = "Authentication method: 'pat' for Personal Access Token or 'github_app' for GitHub App via CodeConnections"
  type        = string
  default     = "pat"

  validation {
    condition     = contains(["pat", "github_app"], var.auth_method)
    error_message = "auth_method must be 'pat' or 'github_app'."
  }
}

variable "github_secret_name" {
  description = "AWS Secrets Manager secret name containing GitHub PAT as plaintext. Secret must exist before running terraform. Create with: aws secretsmanager create-secret --name <name> --secret-string 'ghp_token'"
  type        = string
  default     = ""
}

variable "github_token" {
  description = "GitHub Personal Access Token (use github_secret_name instead for production, only used if auth_method='pat')"
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_connection_arn" {
  description = "Existing AWS CodeConnections connection ARN (use this if connection already exists and is authorized)"
  type        = string
  default     = ""
}

variable "github_connection_name" {
  description = "Name for new AWS CodeConnections connection (module will create it, you authorize in console)"
  type        = string
  default     = ""
}

variable "skip_webhook_creation" {
  description = "Skip webhook creation (useful if you need to populate secret before creating webhook)"
  type        = bool
  default     = false
}

variable "compute_type" {
  description = "CodeBuild compute type"
  type        = string
  default     = "BUILD_GENERAL1_MEDIUM"

  validation {
    condition = contains([
      "BUILD_GENERAL1_SMALL",
      "BUILD_GENERAL1_MEDIUM",
      "BUILD_GENERAL1_LARGE",
      "BUILD_GENERAL1_XLARGE",
      "BUILD_GENERAL1_2XLARGE"
    ], var.compute_type)
    error_message = "Invalid compute type specified."
  }
}

variable "build_image" {
  description = "Docker image for CodeBuild environment"
  type        = string
  default     = "aws/codebuild/standard:7.0"
}

variable "enable_vpc" {
  description = "Whether to create and use VPC"
  type        = bool
  default     = false
}

variable "vpc_config" {
  description = "VPC configuration (required if enable_vpc is true)"
  type = object({
    vpc_id             = string
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "cache_type" {
  description = "Type of cache to use (S3, LOCAL, or NO_CACHE)"
  type        = string
  default     = "S3"

  validation {
    condition     = contains(["S3", "LOCAL", "NO_CACHE"], var.cache_type)
    error_message = "Cache type must be S3, LOCAL, or NO_CACHE."
  }
}

variable "cache_modes" {
  description = "Cache modes for LOCAL cache type"
  type        = list(string)
  default     = ["LOCAL_DOCKER_LAYER_CACHE", "LOCAL_SOURCE_CACHE"]
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch value."
  }
}

variable "enable_docker" {
  description = "Enable Docker in Docker (privileged mode)"
  type        = bool
  default     = true
}

variable "concurrent_build_limit" {
  description = "Maximum number of concurrent builds"
  type        = number
  default     = 20

  validation {
    condition     = var.concurrent_build_limit >= 1 && var.concurrent_build_limit <= 100
    error_message = "Concurrent build limit must be between 1 and 100."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
