output "ecs_service_arn" {
  description = "The ARN of the self-hosted runner ECS service"
  value       = aws_ecs_service.actions-runner.id
}

output "ecs_security_group_id" {
  description = "The security group ID of the self-hosted runner ECS service"
  value       = aws_security_group.ecs_sg.id
}
