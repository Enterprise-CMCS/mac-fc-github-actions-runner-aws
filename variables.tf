# ECR variables

variable "ecr_repo_url" {
  type        = string
  description = "The URL of the github actions ECR repository"
  default     = "037370603820.dkr.ecr.us-east-1.amazonaws.com/github-actions-runner"
}

variable "ecr_repo_tag" {
  type        = string
  description = "The tag to identify and pull the image in ECR repository"
  default     = "latest"
}

# ECS variables

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "ecs_vpc_id" {
  type        = string
  description = "VPC ID to be used by ECS"
}

variable "ecs_subnet_ids" {
  description = "Subnet IDs for the ECS tasks."
  type        = list(string)
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

variable "tags" {
  type        = map(any)
  description = "Additional tags to apply."
  default     = {}
}

# GitHub Runner Variables

variable "personal_access_token_arn" {
  description = "AWS SecretsManager ARN for GitHub personal access token"
  type        = string
}

variable "github_repo_owner" {
  description = "the name of the repo owner"
  type        = string
  default     = "CMSgov"
}

variable "github_repo_name" {
  description = "the name of the repository"
  type        = string
}
