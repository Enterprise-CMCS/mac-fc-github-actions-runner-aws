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

variable "ecr_repository_arns" {
  description = "The ECR ARNs referenced by aws_iam_policy_document task_role_policy_doc"
  type        = list(string)
  default     = ["arn:aws:ecr:us-east-1:037370603820:repository/github-actions-runner"]
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

variable "ecs_task_ingress_sg_ids" {
  description = "The source security group IDs that can ingress to the ECS task."
  type        = set(string)
  default     = []
}

variable "ecs_desired_count" {
  description = "Desired task count for ECS service"
  type        = number
  default     = 0
}

variable "tags" {
  type        = map(any)
  description = "Additional tags to apply."
  default     = {}
}

# Cloudwatch Variables

variable "cloudwatch_log_retention" {
  description = "Number of days to retain logs"
  type        = number
  default     = 731
}

# GitHub Runner Variables

variable "personal_access_token_arn" {
  description = "AWS SecretsManager ARN for GitHub personal access token"
  type        = string
}

variable "github_repo_owner" {
  description = "the name of the repo owner"
  type        = string
  default     = "Enterprise-CMCS"
}

variable "github_repo_name" {
  description = "the name of the repository"
  type        = string
}

variable "runner_labels" {
  description = "Comma-separated list of runner labels"
  type        = string
  default     = ""
}

variable "assign_public_ip" {
  description = "Choose whether to assign a public IP address to the Elastic Network Interface."
  type        = bool
  default     = false
}

variable "role_path" {
  description = "The path in which to create the assume roles and policies. Refer to https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_identifiers.html for more"
  type        = string
  default     = "/"
}

variable "permissions_boundary" {
  description = "ARN of the policy that is used to set the permissions boundary for the role"
  type        = string
  default     = ""
}

variable "task_cpu" {
  description = "The ECS Task CPU size"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "The ECS Task memory size"
  type        = number
  default     = 1024
}

variable "container_cpu" {
  description = "The container CPU size"
  type        = number
  default     = 128
}

variable "container_memory" {
  description = "The container memory size"
  type        = number
  default     = 1024
}
