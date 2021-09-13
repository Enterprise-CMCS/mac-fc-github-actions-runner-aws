locals {
  gh_name_hash     = uuidv5("3505f3f5-f7e4-46df-a7b0-42f7472ebea5", "${var.environment}-${var.github_repo_owner}-${var.github_repo_name}")
  awslogs_group    = split(":", aws_cloudwatch_log_group.main.arn)[6]
}

data "aws_partition" "current" {}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# Assume Role policies

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
  name        = "ecs-gh-runner-${local.gh_name_hash}"
  description = "gh-runner-${local.gh_name_hash} container security group"
  vpc_id      = var.ecs_vpc_id

  tags = {
    Name        = "ecs-gh-runner-${local.gh_name_hash}"
    GHOwner     = var.github_repo_owner
    GHRepo      = var.github_repo_name
    Environment = var.environment
    NameHash    = local.gh_name_hash
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
  description       = "Allow all ingress between resources within this security group"
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
  name               = "cw-target-role-${local.gh_name_hash}"
  description        = "Role allowing CloudWatch Events to run the task"
  assume_role_policy = data.aws_iam_policy_document.events_assume_role_policy.json
}

resource "aws_iam_role_policy" "cloudwatch_target_role_policy" {
  name   = "${aws_iam_role.cloudwatch_target_role.name}-policy"
  role   = aws_iam_role.cloudwatch_target_role.name
  policy = data.aws_iam_policy_document.cloudwatch_target_role_policy_doc.json
}

resource "aws_iam_role" "task_role" {
  name               = "ecs-task-role-${local.gh_name_hash}"
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

    resources = [
      "${aws_cloudwatch_log_group.main.arn}:*"
    ]
  }

  statement {
    actions = [
      "ecr:GetAuthorizationToken",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:/github-runner*",
    ]
  }

  statement {
    actions = [
      "ssm:GetParameters",
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/github-runner*"
    ]
  }
}

# ECS task details

resource "aws_ecs_cluster" "github-runner" {

  name = "gh-runner-${local.gh_name_hash}"

  tags = {
    Name        = "github-runner"
    GHOwner     = var.github_repo_owner
    GHRepo      = var.github_repo_name
    Environment = var.environment
    NameHash    = local.gh_name_hash
    Automation  = "Terraform"
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_ecs_task_definition" "runner_def" {
  family        = "gh-runner-${local.gh_name_hash}"
  network_mode  = "awsvpc"
  task_role_arn = aws_iam_role.task_role.arn

  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.task_role.arn

  container_definitions = templatefile("${path.module}/container-definitions.tpl",
    {
      environment               = var.environment,
      ecr_repo_url              = var.ecr_repo_url,
      ecr_repo_tag              = var.ecr_repo_tag,
      awslogs_group             = local.awslogs_group,
      awslogs_region            = data.aws_region.current.name,
      personal_access_token_arn = var.personal_access_token_arn,
      github_repo_owner         = var.github_repo_owner,
      github_repo_name          = var.github_repo_name
    }
  )

  tags = {
    Name        = "github-runner"
    GHOwner     = var.github_repo_owner
    GHRepo      = var.github_repo_name
    Environment = var.environment
    NameHash    = local.gh_name_hash
    Automation  = "Terraform"
  }
}

resource "aws_ecs_service" "actions-runner" {
  name            = "gh-runner-${local.gh_name_hash}"
  cluster         = aws_ecs_cluster.github-runner[0].arn
  task_definition = aws_ecs_task_definition.runner_def.arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"
  network_configuration {
    subnets         = [for s in var.ecs_subnet_ids : s]
    security_groups = [aws_security_group.ecs_sg.id]
  }

  tags = {
    Name        = "github-runner"
    GHOwner     = var.github_repo_owner
    GHRepo      = var.github_repo_name
    Environment = var.environment
    NameHash    = local.gh_name_hash
    Automation  = "Terraform"
  }

  # we ignore changes to the task_definition and desired_count because
  # github actions workflows manages changes to the task definition and
  # scales up and down the desired count accordingly

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}
