output "runner_label" {
  description = "Runner label for GitHub Actions workflows"
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

output "auth_method" {
  description = "Authentication method in use"
  value       = module.github_runner.auth_method
}

output "github_connection_arn" {
  description = "GitHub App connection ARN (authorize in AWS Console)"
  value       = module.github_runner.github_connection_arn
}

output "github_connection_status" {
  description = "Connection status (PENDING → authorize in console → AVAILABLE)"
  value       = module.github_runner.github_connection_status
}

output "webhook_created" {
  description = "Whether webhook was created (requires AVAILABLE connection)"
  value       = module.github_runner.webhook_created
}

output "setup_complete" {
  description = "Setup instructions"
  value       = module.github_runner.setup_complete
}

output "next_steps" {
  description = "What to do next"
  value       = <<-EOT

    📝 NEXT STEPS:

    ${module.github_runner.github_connection_status == "PENDING" ? "1. Authorize the GitHub App connection:" : ""}
    ${module.github_runner.github_connection_status == "PENDING" ? "   https://console.aws.amazon.com/codesuite/settings/connections" : ""}
    ${module.github_runner.github_connection_status == "PENDING" ? "   Find: mac-fc-test-connection → Update pending connection" : ""}
    ${module.github_runner.github_connection_status == "PENDING" ? "" : ""}
    ${module.github_runner.github_connection_status == "PENDING" ? "2. Re-run terraform apply to create webhook:" : "1. Use this runner label in your GitHub Actions:"}
    ${module.github_runner.github_connection_status == "PENDING" ? "   terraform apply" : "   runs-on: ${module.github_runner.runner_label}"}

    ${module.github_runner.github_connection_status == "PENDING" ? "3. Use this runner label in your GitHub Actions:" : "2. Check logs if needed:"}
    ${module.github_runner.github_connection_status == "PENDING" ? "   runs-on: ${module.github_runner.runner_label}" : "   aws logs tail ${module.github_runner.log_group} --follow"}

    ${module.github_runner.github_connection_status == "PENDING" ? "4. Check logs if needed:" : ""}
    ${module.github_runner.github_connection_status == "PENDING" ? "   aws logs tail ${module.github_runner.log_group} --follow" : ""}
  EOT
}
