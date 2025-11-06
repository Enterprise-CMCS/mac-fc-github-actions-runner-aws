module "github_runner" {
  source = "../.."

  github_owner       = var.github_owner
  github_repository  = var.github_repository
  github_secret_name = var.github_secret_name

  project_name = var.project_name
  environment  = var.environment

  tags = var.tags
}

variable "github_owner" {
  description = "GitHub organization or username"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository name"
  type        = string
}

variable "github_secret_name" {
  description = "AWS Secrets Manager secret name"
  type        = string
  default     = "github/actions/runner-token"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "demo"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default = {
    Example = "basic"
  }
}

output "runner_label" {
  description = "Use this label in your GitHub Actions workflows"
  value       = module.github_runner.runner_label
}

output "project_name" {
  description = "CodeBuild project name"
  value       = module.github_runner.project_name
}

output "log_group" {
  description = "CloudWatch log group for debugging"
  value       = module.github_runner.log_group
}
