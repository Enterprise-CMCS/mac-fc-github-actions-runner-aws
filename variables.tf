# ECR variables

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

# ECS variables

variable "app_name" {
  type        = string
  description = "Name of the application"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "task_name" {
  type        = string
  description = "Name of the task to be run"
}

variable "ecs_vpc_id" {
  type = string
  description = "VPC ID to be used by ECS"
}

variable "ecs_subnet_ids" {
  description = "Subnet IDs for the ECS tasks."
  type        = list(string)
}

variable "repo_tag" {
  type        = string
  description = "The tag to identify and pull the image in ECR repo"
  default     = "latest"
}

variable "logs_cloudwatch_group_arn" {
  description = "CloudWatch log group arn for container logs"
  type        = string
}

 variable "ecs_cluster_arn" {
   description = "ECS cluster ARN to use for running this profile"
   type        = string
   default     = ""
 }

 variable "ecs_desired_count" {
   description = "Desired task count for ECS service"
   type        = number
 }

# GitHub Runner Variables

variable "personal_access_token_arn" {
  description = "AWS SecretsManager ARN for GitHub personal access token"
  type        = string
}

variable "repo_owner" {
  description = "the name of the repo owner"
  type        = string
  default     = "CMSgov"
}

variable "repo_name" {
  description = "the name of the repository"
  type        = string
}
