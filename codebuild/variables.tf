# Required Variables
variable "github_owner" {
  description = "GitHub organization or user name"
  type        = string
}

# Multi-repo mode: Use this to deploy runners for multiple repositories
variable "repositories" {
  description = "Map of repositories (key = repo-name, value = config). Leave empty for single-repo mode."
  type = map(object({
    github_repository      = string
    project_name           = string
    compute_type           = optional(string, "BUILD_GENERAL1_MEDIUM")
    concurrent_build_limit = optional(number, 20)
    skip_webhook_creation  = optional(bool, true)
    enable_docker_server   = optional(bool, false)
  }))
  default = {}
}

# Single-repo mode: Use these when not using repositories map (legacy/backward compat)
variable "github_repository" {
  description = "GitHub repository name (ignored if repositories map is provided)"
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Name prefix for all resources (ignored if repositories map is provided)"
  type        = string
  default     = ""

  validation {
    condition     = var.project_name == "" || can(regex("^[a-z0-9-]+$", var.project_name))
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
  default     = "github_app"

  validation {
    condition     = contains(["pat", "github_app"], var.auth_method)
    error_message = "Authentication method must be either 'pat' or 'github_app'."
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
  description = "Existing AWS CodeConnections connection ARN (REQUIRED when auth_method='github_app' if not using github_connection_name). Use this if connection already exists and is in AVAILABLE status. Get ARN from: AWS Console > Developer Tools > Connections"
  type        = string
  default     = ""
}

variable "github_connection_name" {
  description = "Name for new AWS CodeConnections connection (REQUIRED when auth_method='github_app' if not using github_connection_arn). Module will create connection in PENDING status - you must authorize it in AWS Console before it can be used."
  type        = string
  default     = ""
}

variable "skip_webhook_creation" {
  description = "Skip webhook creation. Default is true for safety. After setting up authentication (and authorizing GitHub App connections in AWS Console), set to false and re-apply to create webhook."
  type        = bool
  default     = true
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

variable "enable_docker" {
  description = "Enable Docker in Docker (privileged mode). In multi-repo mode, applies to all repos unless they set enable_docker_server=true."
  type        = bool
  default     = true
}

variable "enable_docker_server" {
  description = "Enable Docker Server mode (alternative to privileged DinD). Requires standard:7.0+ image. Provides managed Docker daemon without privileged mode. Cannot be used with enable_docker=true."
  type        = bool
  default     = false
}

variable "docker_server_capacity" {
  description = "Base capacity for Docker server fleet (number of Docker daemon instances). Only used when enable_docker_server = true."
  type        = number
  default     = 1

  validation {
    condition     = var.docker_server_capacity >= 1 && var.docker_server_capacity <= 100
    error_message = "Docker server capacity must be between 1 and 100."
  }
}

variable "docker_server_compute_type" {
  description = "Compute type for Docker server fleet. Only used when enable_docker_server = true."
  type        = string
  default     = "BUILD_GENERAL1_SMALL"

  validation {
    condition = contains([
      "BUILD_GENERAL1_SMALL",
      "BUILD_GENERAL1_MEDIUM",
      "BUILD_GENERAL1_LARGE"
    ], var.docker_server_compute_type)
    error_message = "Invalid Docker server compute type. Must be BUILD_GENERAL1_SMALL, MEDIUM, or LARGE."
  }
}

variable "docker_server_overflow_behavior" {
  description = "Fleet overflow behavior (DEPRECATED - ignored). LINUX_EC2 fleets only support QUEUE overflow. Increase docker_server_capacity for concurrent builds."
  type        = string
  default     = "QUEUE"

  validation {
    condition     = contains(["QUEUE", "ON_DEMAND"], var.docker_server_overflow_behavior)
    error_message = "Overflow behavior must be either QUEUE or ON_DEMAND."
  }
}

variable "docker_server_subnet_id" {
  description = "Single subnet ID for Docker Server fleet. AWS CodeBuild Fleet supports only ONE subnet. If not specified, uses the first subnet from vpc_config.subnet_ids. Only used when enable_docker_server = true."
  type        = string
  default     = ""
}

variable "enable_vpc" {
  description = "Whether to create and use VPC"
  type        = bool
  default     = true
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

variable "managed_security_groups" {
  description = "Create and use managed security groups for the CodeBuild project. Requires enable_vpc = true."
  type        = bool
  default     = true
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

variable "s3_cache_sse_mode" {
  description = "Server-side encryption mode for S3 cache bucket: SSE_S3 (default) or SSE_KMS."
  type        = string
  default     = "SSE_S3"

  validation {
    condition     = contains(["SSE_S3", "SSE_KMS"], var.s3_cache_sse_mode)
    error_message = "S3 cache SSE mode must be either 'SSE_S3' or 'SSE_KMS'."
  }
}

variable "s3_cache_kms_key_arn" {
  description = "KMS key ARN for S3 cache bucket when s3_cache_sse_mode = 'SSE_KMS'. If empty and SSE_KMS is selected, a new key will be created."
  type        = string
  default     = ""
}

variable "s3_cache_enable_versioning" {
  description = "Enable S3 bucket versioning for the cache bucket (optional; may increase cost)."
  type        = bool
  default     = false
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

variable "cloudwatch_kms_key_arn" {
  description = "Optional KMS key ARN for encrypting CloudWatch Logs. If set, the log group will use this key."
  type        = string
  default     = ""
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
