output "project_names" {
  description = "CodeBuild project names (map: repo-key => project-name)"
  value       = { for k, v in aws_codebuild_project.runner : k => v.name }
}

output "project_arns" {
  description = "CodeBuild project ARNs (map: repo-key => project-arn)"
  value       = { for k, v in aws_codebuild_project.runner : k => v.arn }
}

output "runner_labels" {
  description = "Runner labels for GitHub Actions workflows (map: repo-key => runner-label)"
  value       = { for k, v in aws_codebuild_project.runner : k => "codebuild-${v.name}-$${{github.run_id}}-$${{github.run_attempt}}" }
}

output "log_groups" {
  description = "CloudWatch log groups (map: repo-key => log-group-name)"
  value       = { for k, v in aws_cloudwatch_log_group.runner : k => v.name }
}

output "webhooks_created" {
  description = "Webhooks created status (map: repo-key => webhook-created)"
  value       = { for k, v in local.repos : k => !v.skip_webhook_creation }
}

output "service_role_arn" {
  description = "CodeBuild service role ARN"
  value       = aws_iam_role.codebuild.arn
}

output "codebuild_security_group_id" {
  description = "CodeBuild project security group ID (use this to allow access to Redshift/RDS/ElastiCache/etc)"
  value       = var.enable_vpc && var.vpc_config != null && var.managed_security_groups ? aws_security_group.codebuild_managed[0].id : null
}

output "cache_bucket" {
  description = "S3 cache bucket name (if enabled)"
  value       = var.cache_type == "S3" ? aws_s3_bucket.cache[0].id : null
}

output "docker_modes" {
  description = "Docker mode per repo (map: repo-key => docker-mode)"
  value       = { for k, v in local.repos : k => v.enable_docker_server ? "server" : "none" }
}

output "docker_server_fleet_arn" {
  description = "Docker Server fleet ARN (shared across repos that use Docker Server)"
  value       = local.need_docker_fleet ? aws_codebuild_fleet.docker_server[0].arn : null
}

output "github_repository_urls" {
  description = "GitHub repository URLs (map: repo-key => repo-url)"
  value       = { for k, v in local.repos : k => "https://github.com/${var.github_owner}/${v.github_repository}" }
}

output "auth_method" {
  description = "Authentication method in use"
  value       = var.auth_method
}

output "github_connection_arn" {
  description = "GitHub App CodeConnections ARN (if using github_app auth)"
  value       = var.auth_method == "github_app" ? local.github_connection_arn : null
}

output "github_connection_status" {
  description = "CodeConnections connection status (only if connection was created by module)"
  value       = var.auth_method == "github_app" && var.github_connection_name != "" ? aws_codeconnections_connection.github[0].connection_status : null
}

output "setup_complete" {
  description = "Setup status and next steps"
  value       = local.setup_instructions
}

locals {
  webhooks_status = alltrue([for k, v in local.repos : !v.skip_webhook_creation]) ? "all created" : (
    anytrue([for k, v in local.repos : !v.skip_webhook_creation]) ? "partially created" : "all skipped"
  )

  setup_instructions = var.auth_method == "github_app" ? (
    var.github_connection_name != "" ? join("", [
      "✅ GitHub App Authentication Configured\n\n",
      "⚠️  MANUAL STEP REQUIRED - Authorize the connection:\n\n",
      "Connection Name: ${var.github_connection_name}\n",
      "Connection ARN:  ${aws_codeconnections_connection.github[0].arn}\n",
      "Status:          ${aws_codeconnections_connection.github[0].connection_status}\n\n",
      "Steps to authorize:\n",
      "1. Go to: https://console.aws.amazon.com/codesuite/settings/connections\n",
      "2. Find connection: \"${var.github_connection_name}\"\n",
      "3. Click \"Update pending connection\"\n",
      "4. Sign in to GitHub and select your GitHub App\n",
      "5. Connection status will change from PENDING → AVAILABLE\n",
      local.webhooks_status == "all created" ? "6. Webhooks already created ✅\n\n" : (
        local.webhooks_status == "all skipped" ?
        "6. Set skip_webhook_creation = false for repos in your config\n7. Run 'terraform apply' again to create webhooks\n\n" :
        "6. Some webhooks created, check webhooks_created output\n\n"
      ),
      "Once authorized, CodeBuild can automatically use GitHub App tokens.\n\n",
      "Security benefits:\n",
      "- ✅ 1-hour token lifetime (vs 7-90 days for PAT)\n",
      "- ✅ No user dependency (persists when employees leave)\n",
      "- ✅ Better rate limits (12,500-15,000 vs 5,000 req/hr)\n"
      ]) : join("", [
      "✅ GitHub App Authentication Configured (Using Existing Connection)\n\n",
      "Connection ARN: ${var.github_connection_arn}\n\n",
      "ℹ️  Using your existing CodeConnections connection.\n",
      "Ensure it's authorized and in AVAILABLE status.\n\n",
      "To check status:\n",
      "aws codeconnections get-connection --connection-arn ${var.github_connection_arn}\n\n",
      "Security benefits:\n",
      "- ✅ 1-hour token lifetime (vs 7-90 days for PAT)\n",
      "- ✅ No user dependency\n",
      "- ✅ Better rate limits (12,500-15,000 vs 5,000 req/hr)\n"
    ])
    ) : (
    # PAT authentication
    local.webhooks_status == "all skipped" ? join("", [
      "⚠️  Webhook Creation Skipped\n\n",
      "Secret: ${var.github_secret_name}\n",
      "Webhooks: Skipped (skip_webhook_creation = true)\n\n",
      "📋 To complete setup:\n\n",
      "1. Ensure secret contains valid GitHub Personal Access Token:\n\n",
      "   aws secretsmanager put-secret-value \\\n",
      "     --secret-id ${var.github_secret_name} \\\n",
      "     --secret-string 'ghp_your_token_here'\n\n",
      "2. Set skip_webhook_creation = false for repos\n\n",
      "3. Run 'terraform apply' to create webhooks\n\n",
      "Token Requirements:\n",
      "- Classic PAT: 'repo' and 'admin:repo_hook' scopes\n",
      "- Fine-grained PAT: 'Actions: read+write' and 'Metadata: read'\n"
      ]) : join("", [
      "✅ Personal Access Token Authentication Configured\n\n",
      "Secret: ${var.github_secret_name}\n",
      "Webhooks: ${local.webhooks_status}\n",
      "Status: Ready to use!\n\n",
      "💡 For production, consider GitHub App authentication:\n",
      "- Set auth_method = \"github_app\"\n",
      "- Provides 1-hour auto-refreshing tokens\n",
      "- Better security and rate limits\n"
    ])
  )
}

output "usage_instructions" {
  description = "How to use this runner in GitHub Actions"
  value       = <<-EOT
    GitHub Actions Workflow Usage:
    ==============================

    Add this to your workflow file (.github/workflows/*.yml):

    jobs:
      my-job:
        runs-on: codebuild-<PROJECT_NAME>-$${{github.run_id}}-$${{github.run_attempt}}
        steps:
          - uses: actions/checkout@v4
          - run: echo "Running on CodeBuild!"

    Replace <PROJECT_NAME> with your CodeBuild project name.
    Check the 'project_names' output for exact project names.

    Example for multi-repo setup:
    - repo "mac-fc-embedded" → runs-on: codebuild-test-runner-github-app-dev-runner-$${{github.run_id}}-$${{github.run_attempt}}
  EOT
}
