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
  default     = "github_app"

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
  description = "Enable Docker in Docker (privileged mode)"
  type        = bool
  default     = true
}

variable "enable_docker_server" {
  description = "Enable Docker Server mode (alternative to privileged DinD). Requires standard:7.0+ image. Provides managed Docker daemon without privileged mode."
  type        = bool
  default     = false
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
  description = "Create and use managed security groups for the CodeBuild project and Docker server fleet (restricts Docker port 9876 to project SG). Requires enable_vpc = true."
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
    error_message = "s3_cache_sse_mode must be SSE_S3 or SSE_KMS."
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

variable "docker_server_capacity" {
  description = "Base capacity for Docker server fleet (number of reserved Docker daemon instances). AWS requires minimum 1. Set to 1 for most cost-effective mode with on-demand overflow."
  type        = number
  default     = 1

  validation {
    condition     = var.docker_server_capacity >= 1 && var.docker_server_capacity <= 100
    error_message = "Docker server capacity must be between 1 and 100 (AWS minimum is 1)."
  }
}

variable "docker_server_compute_type" {
  description = "Compute type for Docker server fleet"
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
  description = "Fleet overflow behavior when base capacity is full. QUEUE (default) waits for capacity, ON_DEMAND provisions on-demand instances."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["QUEUE", "ON_DEMAND"], var.docker_server_overflow_behavior)
    error_message = "Overflow behavior must be QUEUE or ON_DEMAND."
  }
}

variable "docker_server_subnet_id" {
  description = "Subnet ID to use for the Docker server fleet (CodeBuild fleet currently supports a single subnet). If not set, the first subnet in vpc_config.subnet_ids is used."
  type        = string
  default     = ""
}

variable "docker_server_host" {
  description = "Hostname or IP for Docker Server endpoint. Leave empty to let CodeBuild auto-configure (recommended)."
  type        = string
  default     = ""
}

variable "docker_server_port" {
  description = "Port for Docker Server endpoint used by the build container. AWS Docker Server uses port 9876."
  type        = number
  default     = 9876
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
