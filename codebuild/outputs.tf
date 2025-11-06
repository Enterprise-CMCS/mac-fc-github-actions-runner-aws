output "project_name" {
  description = "CodeBuild project name"
  value       = aws_codebuild_project.runner.name
}

output "project_arn" {
  description = "CodeBuild project ARN"
  value       = aws_codebuild_project.runner.arn
}

output "runner_label" {
  description = "Runner label to use in GitHub Actions workflows"
  value       = "codebuild-${aws_codebuild_project.runner.name}-$${{github.run_id}}-$${{github.run_attempt}}"
}

output "runner_label_template" {
  description = "Runner label template with placeholders"
  value       = "codebuild-${aws_codebuild_project.runner.name}-<RUN_ID>-<RUN_ATTEMPT>"
}

output "webhook_url" {
  description = "Webhook URL (null if webhook not created yet)"
  value       = local.can_create_webhook ? aws_codebuild_webhook.runner[0].url : null
  sensitive   = true
}

output "webhook_payload_url" {
  description = "Webhook payload URL (null if webhook not created yet)"
  value       = local.can_create_webhook ? aws_codebuild_webhook.runner[0].payload_url : null
  sensitive   = true
}

output "webhook_created" {
  description = "Whether webhook was created"
  value       = local.can_create_webhook
}

output "log_group" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.runner.name
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

output "privileged_mode" {
  description = "Whether privileged mode is enabled for Docker-in-Docker"
  value       = var.enable_docker
}

output "github_repository_url" {
  description = "GitHub repository URL"
  value       = "https://github.com/${var.github_owner}/${var.github_repository}"
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
      var.skip_webhook_creation ?
      "6. Set skip_webhook_creation = false in your config\n" :
      "6. Webhook already created ✅\n",
      var.skip_webhook_creation ?
      "7. Run 'terraform apply' again to create the webhook\n\n" :
      "\n",
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
    var.skip_webhook_creation ? join("", [
      "⚠️  Webhook Creation Skipped\n\n",
      "Secret: ${var.github_secret_name}\n",
      "Webhook: Skipped (skip_webhook_creation = true)\n\n",
      "📋 To complete setup:\n\n",
      "1. Ensure secret contains valid GitHub Personal Access Token:\n\n",
      "   aws secretsmanager put-secret-value \\\n",
      "     --secret-id ${var.github_secret_name} \\\n",
      "     --secret-string 'ghp_your_token_here'\n\n",
      "2. Set skip_webhook_creation = false\n\n",
      "3. Run 'terraform apply' to create the webhook\n\n",
      "Token Requirements:\n",
      "- Classic PAT: 'repo' and 'admin:repo_hook' scopes\n",
      "- Fine-grained PAT: 'Actions: read+write' and 'Metadata: read'\n"
      ]) : join("", [
      "✅ Personal Access Token Authentication Configured\n\n",
      "Secret: ${var.github_secret_name}\n",
      "Webhook: ✅ Created\n",
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

    Add this to your workflow file:

    jobs:
      my-job:
        runs-on: ${local.resource_prefix}-runner-$${{github.run_id}}-$${{github.run_attempt}}
        steps:
          - uses: actions/checkout@v4
          - run: echo "Running on CodeBuild!"

    Or use the full label:

    runs-on: codebuild-${aws_codebuild_project.runner.name}-$${{github.run_id}}-$${{github.run_attempt}}
  EOT
}
