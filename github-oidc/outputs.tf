output "github_oidc_role_arn" {
  description = "The ARN of the role assumed by the AWS OIDC identity provider"
  value       = aws_iam_role.github_actions_oidc.arn
}
