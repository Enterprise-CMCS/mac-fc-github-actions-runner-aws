output "ecs_service_arn" {
  description = "The ARN of the self-hosted runner ECS service"
  value       = aws_ecs_service.actions-runner.id
}
