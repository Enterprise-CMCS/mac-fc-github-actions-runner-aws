terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# GitHub App authentication
module "github_runner" {
  source = "../terraform-aws-codebuild-github-runner"

  # Authentication (GitHub App method - recommended for production)
  auth_method            = "github_app"
  github_connection_name = var.github_connection_name

  # Alternative: PAT authentication
  # auth_method        = "pat"
  # github_secret_name = "github/actions/runner-token"

  # Repository configuration
  github_owner      = var.github_owner
  github_repository = var.github_repository

  # Project configuration
  project_name = var.project_name
  environment  = var.environment

  # Optional: Compute configuration
  compute_type           = var.compute_type
  concurrent_build_limit = var.concurrent_build_limit

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Test        = "true"
  }
}
