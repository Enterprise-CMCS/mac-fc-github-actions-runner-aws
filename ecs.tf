locals {
  awslogs_group    = split(":", var.logs_cloudwatch_group_arn)[6]
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "cloudwatch_logs_allow_kms" {
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
      ]
    }

    actions = [
      "kms:*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "Allow logs KMS access"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }

    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    resources = ["*"]
  }
}

# Create a data source to pull the latest active revision from
# data "aws_ecs_task_definition" "runner_def" {
#   task_definition = aws_ecs_task_definition.runner_def.family
#   depends_on      = [aws_ecs_task_definition.runner_def] # ensures at least one task def exists
# }

# Assume Role policies

data "aws_partition" "current" {}

data "aws_region" "current" {}

data "aws_iam_policy_document" "ecs_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    effect = "Allow"
  }
}

data "aws_iam_policy_document" "events_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    effect = "Allow"
  }
}

# SG - ECS

resource "aws_security_group" "ecs_sg" {
  name        = "ecs-${var.app_name}-${var.environment}"
  description = "${var.app_name}-${var.environment} container security group"
  vpc_id      = var.ecs_vpc_id

  tags = {
    Name        = "ecs-${var.app_name}-${var.environment}"
    Environment = var.environment
    Automation  = "Terraform"
  }
}

resource "aws_security_group_rule" "app_ecs_allow_outbound" {
  description       = "Allow all outbound"
  security_group_id = aws_security_group.ecs_sg.id

  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_self" {
  type              = "ingress"
  to_port           = -1
  from_port         = -1
  protocol          = "all"
  security_group_id = aws_security_group.ecs_sg.id
  self              = true
}

## ECS schedule task

# Allows CloudWatch Rule to run ECS Task

data "aws_iam_policy_document" "cloudwatch_target_role_policy_doc" {
  statement {
    actions   = ["iam:PassRole"]
    resources = ["*"]
  }

  statement {
    actions   = ["ecs:RunTask"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "cloudwatch_target_role" {
  name               = "cw-target-role-${var.app_name}-${var.environment}-${var.task_name}"
  description        = "Role allowing CloudWatch Events to run the task"
  assume_role_policy = data.aws_iam_policy_document.events_assume_role_policy.json
}

resource "aws_iam_role_policy" "cloudwatch_target_role_policy" {
  name   = "${aws_iam_role.cloudwatch_target_role.name}-policy"
  role   = aws_iam_role.cloudwatch_target_role.name
  policy = data.aws_iam_policy_document.cloudwatch_target_role_policy_doc.json
}

resource "aws_iam_role" "task_role" {
  name               = "ecs-task-role-${var.app_name}-${var.environment}-${var.task_name}"
  description        = "Role allowing container definition to execute"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json
}

resource "aws_iam_role_policy" "task_role_policy" {
  name   = "${aws_iam_role.task_role.name}-policy"
  role   = aws_iam_role.task_role.name
  policy = data.aws_iam_policy_document.task_role_policy_doc.json
}

data "aws_iam_policy_document" "task_role_policy_doc" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["${var.logs_cloudwatch_group_arn}:*"]
  }

  statement {
    actions = [
      "ecr:GetAuthorizationToken",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]

    resources = [aws_ecr_repository.main.arn]
  }

  statement {
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:/${var.app_name}-${var.environment}*",
    ]
  }

  statement {
    actions = [
      "ssm:GetParameters",
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${var.app_name}-${var.environment}*"
    ]
  }
}

# ECS task details

resource "aws_ecs_cluster" "github-runner" {
  name = var.app_name

  tags = {
    Environment = var.environment
    Automation  = "Terraform"
  }
  lifecycle {
    create_before_destroy = true
  }
}

# resource "aws_ecs_task_definition" "runner_def" {
#   family        = "${var.app_name}-${var.environment}-${var.task_name}"
#   network_mode  = "awsvpc"
#   task_role_arn = aws_iam_role.task_role.arn

#   requires_compatibilities = ["FARGATE"]
#   cpu                      = "256"
#   memory                   = "1024"
#   execution_role_arn       = aws_iam_role.task_role.arn

#   container_definitions = templatefile("${path.module}/container-definitions.tpl",
#     {
#       app_name = var.app_name,
#       environment = var.environment,
#       task_name = var.task_name,
#       repo_url = aws_ecr_repository.main.repository_url,
#       repo_tag = var.repo_tag,
#       awslogs_group = local.awslogs_group,
#       awslogs_region = data.aws_region.current.name,
#       personal_access_token_arn = var.personal_access_token_arn,
#       repo_owner = var.repo_owner,
#       repo_name = var.repo_name
#     }
#   )
# }

resource "aws_ecs_service" "actions-runner" {
  name = "github-actions-runner"
  cluster = aws_ecs_cluster.github-runner.arn
  launch_type = "FARGATE"
  network_configuration {
    subnets = [for s in var.ecs_subnet_ids: s]
    security_groups = [aws_security_group.ecs_sg.id]
  }
}