# CodeBuild Service Role
resource "aws_iam_role" "codebuild" {
  name = "${local.resource_prefix}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
    }]
  })

  tags = local.default_tags

  # Wait for secret validation to pass (for PAT auth)
  depends_on = [null_resource.validate_secret]
}

# Docker Server Fleet Service Role (only when VPC is enabled)
resource "aws_iam_role" "fleet" {
  count = var.enable_docker_server && var.enable_vpc ? 1 : 0
  name  = "${local.resource_prefix}-fleet-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
    }]
  })

  tags = merge(local.default_tags, {
    Name = "${local.resource_prefix}-fleet-role"
  })
}

# Fleet VPC Policy
resource "aws_iam_role_policy" "fleet_vpc" {
  count = var.enable_docker_server && var.enable_vpc ? 1 : 0
  name  = "${local.resource_prefix}-fleet-vpc-policy"
  role  = aws_iam_role.fleet[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeDhcpOptions",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVpcs",
          "ec2:ModifyNetworkInterfaceAttribute",
          "ec2:CreateNetworkInterfacePermission"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterfacePermission"
        ]
        Resource = "arn:aws:ec2:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:network-interface/*"
        Condition = {
          StringEquals = {
            "ec2:Subnet" = var.vpc_config != null ? var.vpc_config.subnet_ids : []
          }
        }
      }
    ]
  })
}

# CodeBuild Base Policy
resource "aws_iam_role_policy" "codebuild" {
  name = "${local.resource_prefix}-codebuild-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          aws_cloudwatch_log_group.runner.arn,
          "${aws_cloudwatch_log_group.runner.arn}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:CreateReportGroup",
          "codebuild:CreateReport",
          "codebuild:UpdateReport",
          "codebuild:BatchPutTestCases"
        ]
        Resource = "arn:aws:codebuild:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:report-group/*"
      }
    ]
  })
}

# S3 Cache Policy
resource "aws_iam_role_policy" "codebuild_cache" {
  count = var.cache_type == "S3" ? 1 : 0
  name  = "${local.resource_prefix}-codebuild-cache-policy"
  role  = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.cache[0].arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.cache[0].arn
      }
    ]
  })
}

# VPC Policy
resource "aws_iam_role_policy" "codebuild_vpc" {
  count = var.enable_vpc ? 1 : 0
  name  = "${local.resource_prefix}-codebuild-vpc-policy"
  role  = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:CreateNetworkInterfacePermission",
          "ec2:DescribeDhcpOptions",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AttachNetworkInterface",
          "ec2:DetachNetworkInterface",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVpcs"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterfacePermission"
        ]
        Resource = "arn:aws:ec2:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:network-interface/*"
        Condition = {
          StringEquals = {
            "ec2:Subnet" = var.vpc_config != null ? var.vpc_config.subnet_ids : []
          }
        }
      }
    ]
  })
}

# Secrets Manager Policy
resource "aws_iam_role_policy" "codebuild_secrets" {
  count = var.github_secret_name != "" ? 1 : 0
  name  = "${local.resource_prefix}-codebuild-secrets-policy"
  role  = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue"
      ]
      Resource = "arn:aws:secretsmanager:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:secret:${var.github_secret_name}*"
    }]
  })
}

# ECR Policy (for Docker images)
resource "aws_iam_role_policy" "codebuild_ecr" {
  count = var.enable_docker ? 1 : 0
  name  = "${local.resource_prefix}-codebuild-ecr-policy"
  role  = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ]
      Resource = "*"
    }]
  })
}

# KMS policy for S3 cache when using SSE-KMS
resource "aws_iam_role_policy" "codebuild_kms_s3_cache" {
  count = var.cache_type == "S3" && var.s3_cache_sse_mode == "SSE_KMS" ? 1 : 0
  name  = "${local.resource_prefix}-codebuild-kms-s3-cache-policy"
  role  = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = var.s3_cache_kms_key_arn != "" ? var.s3_cache_kms_key_arn : aws_kms_key.s3_cache[0].arn
      }
    ]
  })
}

# Webhook Management Policy
resource "aws_iam_role_policy" "codebuild_webhook" {
  name = "${local.resource_prefix}-codebuild-webhook-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "codebuild:CreateWebhook",
        "codebuild:UpdateWebhook",
        "codebuild:DeleteWebhook"
      ]
      Resource = aws_codebuild_project.runner.arn
    }]
  })
}

# CodeConnections Policy (for GitHub App authentication)
resource "aws_iam_role_policy" "codebuild_codeconnections" {
  count = var.auth_method == "github_app" ? 1 : 0
  name  = "${local.resource_prefix}-codebuild-codeconnections-policy"
  role  = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "codeconnections:GetConnectionToken",
        "codeconnections:GetConnection",
        "codeconnections:UseConnection"
      ]
      Resource = local.github_connection_arn
    }]
  })
}
