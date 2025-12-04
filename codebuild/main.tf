locals {
  # Validation: ensure either repositories OR single-repo vars are provided
  _ = length(var.repositories) > 0 || (var.github_repository != "" && var.project_name != "") ? null : file("ERROR: Either provide repositories map OR set github_repository and project_name for single-repo mode")

  # Mode: multi-repo if repositories map provided, single-repo otherwise
  is_multi_repo = length(var.repositories) > 0

  # Normalize: convert single-repo vars to same format as multi-repo
  repos = local.is_multi_repo ? var.repositories : {
    "default" = {
      github_repository      = var.github_repository
      project_name           = var.project_name
      compute_type           = var.compute_type
      concurrent_build_limit = var.concurrent_build_limit
      skip_webhook_creation  = var.skip_webhook_creation
      enable_docker_server   = var.enable_docker_server
    }
  }

  # Shared resource prefix (S3, SG, Fleet)
  # Multi-repo: github_owner-environment, Single-repo: project_name-environment (backward compat)
  shared_prefix = local.is_multi_repo ? "${var.github_owner}-${var.environment}" : "${var.project_name}-${var.environment}"

  # S3 bucket prefix (lowercase, max 41 chars to allow for "-runner-cache-" + 8 char hex = 63 total)
  s3_prefix = substr(lower(local.shared_prefix), 0, 41)

  # Check if any repo needs Docker Server (for fleet creation)
  need_docker_fleet = anytrue([for r in local.repos : r.enable_docker_server])

  # Get GitHub token from Secrets Manager or variable (for PAT auth only)
  github_token = var.auth_method == "pat" ? coalesce(
    var.github_token,
    var.github_secret_name != "" ? data.aws_secretsmanager_secret_version.github[0].secret_string : ""
  ) : ""

  # Determine GitHub connection ARN (for GitHub App auth)
  github_connection_arn = var.auth_method == "github_app" ? (
    var.github_connection_arn != "" ? var.github_connection_arn : try(aws_codeconnections_connection.github[0].arn, "")
  ) : ""

  default_tags = merge(
    var.tags,
    {
      Module      = "terraform-aws-codebuild-github-runner"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# VPC data source for security group rules (fallback default SG case)
data "aws_vpc" "selected" {
  count = var.enable_vpc && var.vpc_config != null ? 1 : 0
  id    = var.vpc_config.vpc_id
}

# Validate secret exists before proceeding (for PAT auth)
# This checks the secret exists via AWS CLI before Terraform tries to read it
resource "null_resource" "validate_secret" {
  count = var.auth_method == "pat" && var.github_secret_name != "" && var.github_token == "" ? 1 : 0

  triggers = {
    secret_name = var.github_secret_name
    region      = data.aws_region.current.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Validating GitHub secret exists..."
      if ! aws secretsmanager describe-secret \
        --secret-id "${var.github_secret_name}" \
        --region ${data.aws_region.current.id} > /dev/null 2>&1; then

        echo ""
        echo "❌ ERROR: GitHub secret '${var.github_secret_name}' not found!"
        echo ""
        echo "Create the secret with:"
        echo ""
        echo "aws secretsmanager create-secret \\\"
        echo "  --name ${var.github_secret_name} \\\"
        echo "  --description 'GitHub PAT for CodeBuild runner' \\\"
        echo "  --secret-string 'ghp_your_actual_token_here' \\\"
        echo "  --region ${data.aws_region.current.id}"
        echo ""
        echo "Token Requirements:"
        echo "- Classic PAT: 'repo' and 'admin:repo_hook' scopes"
        echo "- Fine-grained PAT: 'Actions: read+write' and 'Metadata: read'"
        echo "- Get token at: https://github.com/settings/tokens"
        echo ""
        echo "Or switch to GitHub App authentication (no secrets needed!):"
        echo "- Set auth_method = \"github_app\""
        echo ""
        exit 1
      fi
      echo "✅ Secret '${var.github_secret_name}' found"
    EOT
  }
}

# Get GitHub token from Secrets Manager (for PAT auth)
data "aws_secretsmanager_secret_version" "github" {
  count     = var.auth_method == "pat" && var.github_secret_name != "" ? 1 : 0
  secret_id = var.github_secret_name

  depends_on = [null_resource.validate_secret]
}

# Create CodeConnections connection (optional, for GitHub App auth)
resource "aws_codeconnections_connection" "github" {
  count = var.auth_method == "github_app" && var.github_connection_name != "" ? 1 : 0

  name          = var.github_connection_name
  provider_type = "GitHub"

  tags = merge(local.default_tags, {
    Name = var.github_connection_name
  })
}

# Random suffix for unique S3 bucket name
resource "random_id" "bucket_suffix" {
  byte_length = 4

  # Wait for secret validation to pass (for PAT auth)
  depends_on = [null_resource.validate_secret]
}

# S3 bucket for cache (shared across all repos)
resource "aws_s3_bucket" "cache" {
  count = var.cache_type == "S3" ? 1 : 0

  bucket        = "${local.s3_prefix}-runner-cache-${random_id.bucket_suffix.hex}"
  force_destroy = true

  tags = merge(local.default_tags, {
    Name = "${local.shared_prefix}-runner-cache"
  })
}

# Optional: S3 default encryption for cache bucket
resource "aws_kms_key" "s3_cache" {
  count                   = var.cache_type == "S3" && var.s3_cache_sse_mode == "SSE_KMS" && var.s3_cache_kms_key_arn == "" ? 1 : 0
  description             = "KMS key for CodeBuild runner S3 cache"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = local.default_tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cache" {
  count  = var.cache_type == "S3" ? 1 : 0
  bucket = aws_s3_bucket.cache[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.s3_cache_sse_mode == "SSE_KMS" ? "aws:kms" : "AES256"
      kms_master_key_id = var.s3_cache_sse_mode == "SSE_KMS" ? (var.s3_cache_kms_key_arn != "" ? var.s3_cache_kms_key_arn : aws_kms_key.s3_cache[0].arn) : null
    }
  }
}

# Optional: enforce TLS for S3 access
resource "aws_s3_bucket_policy" "cache_tls_only" {
  count  = var.cache_type == "S3" ? 1 : 0
  bucket = aws_s3_bucket.cache[0].id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "DenyInsecureTransport",
        Effect    = "Deny",
        Principal = "*",
        Action    = "s3:*",
        Resource = [
          aws_s3_bucket.cache[0].arn,
          "${aws_s3_bucket.cache[0].arn}/*"
        ],
        Condition = {
          Bool = { "aws:SecureTransport" = false }
        }
      }
    ]
  })
}

# Optional: versioning for cache bucket
resource "aws_s3_bucket_versioning" "cache" {
  count  = var.cache_type == "S3" && var.s3_cache_enable_versioning ? 1 : 0
  bucket = aws_s3_bucket.cache[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "cache" {
  count = var.cache_type == "S3" ? 1 : 0

  bucket = aws_s3_bucket.cache[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "cache" {
  count = var.cache_type == "S3" ? 1 : 0

  bucket = aws_s3_bucket.cache[0].id

  rule {
    id     = "expire-cache"
    status = "Enabled"

    filter {}

    expiration {
      days = 7
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }
}

# CloudWatch Log Groups (one per repo)
resource "aws_cloudwatch_log_group" "runner" {
  for_each = local.repos

  name              = "/aws/codebuild/${each.value.project_name}-${var.environment}-runner"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.cloudwatch_kms_key_arn != "" ? var.cloudwatch_kms_key_arn : null

  tags = local.default_tags

  # Wait for secret validation to pass (for PAT auth)
  depends_on = [null_resource.validate_secret]
}

# Default Security Group for CodeBuild Project
# Auto-created when security_group_ids is empty (fallback)
resource "aws_security_group" "codebuild_default" {
  count = var.enable_vpc && var.vpc_config != null && length(var.vpc_config.security_group_ids) == 0 && !var.managed_security_groups ? 1 : 0

  name        = "${local.shared_prefix}-codebuild-default-sg"
  description = "Default security group for CodeBuild project"
  vpc_id      = var.vpc_config.vpc_id

  # Egress: Allow all outbound (for pulling images from Docker Hub, ECR, GitHub, etc.)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.default_tags, {
    Name = "${local.shared_prefix}-codebuild-default-sg"
  })
}

# Managed security group for CodeBuild project (recommended)
# Provides egress-only access
resource "aws_security_group" "codebuild_managed" {
  count       = var.enable_vpc && var.vpc_config != null && var.managed_security_groups ? 1 : 0
  name        = "${local.shared_prefix}-codebuild-managed-sg"
  description = "Managed security group for CodeBuild project"
  vpc_id      = var.vpc_config.vpc_id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.default_tags, { Name = "${local.shared_prefix}-codebuild-managed-sg" })
}

# Security group rule for Docker Server communication on port 9876 (shared across all repos)
resource "aws_security_group_rule" "docker_server_ingress" {
  count = var.enable_vpc && var.vpc_config != null && var.managed_security_groups && local.need_docker_fleet ? 1 : 0

  type              = "ingress"
  from_port         = 9876
  to_port           = 9876
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.codebuild_managed[0].id
  description       = "Allow Docker Server communication on port 9876"
}

# Import GitHub credentials at account level (PAT method)
resource "null_resource" "import_credentials_pat" {
  count = var.auth_method == "pat" ? 1 : 0

  triggers = {
    token_hash = md5(local.github_token)
    region     = data.aws_region.current.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Importing GitHub PAT credentials to CodeBuild..."
      aws codebuild import-source-credentials \
        --token "${local.github_token}" \
        --server-type GITHUB \
        --auth-type PERSONAL_ACCESS_TOKEN \
        --should-overwrite \
        --region ${self.triggers.region} || true
    EOT
  }

  depends_on = [null_resource.validate_secret]
}

# Import GitHub credentials at account level (GitHub App method)
resource "null_resource" "import_credentials_github_app" {
  count = var.auth_method == "github_app" ? 1 : 0

  triggers = {
    connection_arn = local.github_connection_arn
    region         = data.aws_region.current.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Importing GitHub App credentials via CodeConnections to CodeBuild..."
      aws codebuild import-source-credentials \
        --token "${local.github_connection_arn}" \
        --server-type GITHUB \
        --auth-type CODECONNECTIONS \
        --should-overwrite \
        --region ${self.triggers.region} || true
    EOT
  }

  depends_on = [aws_codeconnections_connection.github]
}

# ============================================================================
# Docker Server Fleet (Optional)
# ============================================================================

# CodeBuild Fleet for Docker Server mode (shared across all repos)
resource "aws_codebuild_fleet" "docker_server" {
  count = local.need_docker_fleet ? 1 : 0

  base_capacity = var.docker_server_capacity
  compute_type  = var.docker_server_compute_type

  # LINUX_EC2 required for Docker Server mode
  environment_type = "LINUX_EC2"

  name = "${local.shared_prefix}-docker-server"

  # LINUX_EC2 fleets only support QUEUE overflow behavior
  overflow_behavior = "QUEUE"

  # Fleet service role required when using VPC
  fleet_service_role = var.enable_vpc && var.vpc_config != null ? aws_iam_role.fleet[0].arn : null

  # VPC configuration for fleet (not project when using fleet)
  dynamic "vpc_config" {
    for_each = var.enable_vpc && var.vpc_config != null ? [1] : []
    content {
      vpc_id = var.vpc_config.vpc_id

      # Fleet supports only ONE subnet (use first from list or override with docker_server_subnet_id)
      subnets = [
        var.docker_server_subnet_id != "" ? var.docker_server_subnet_id : var.vpc_config.subnet_ids[0]
      ]

      security_group_ids = var.managed_security_groups ? [
        aws_security_group.codebuild_managed[0].id
        ] : (
        length(var.vpc_config.security_group_ids) > 0 ? var.vpc_config.security_group_ids : [
          aws_security_group.codebuild_default[0].id
        ]
      )
    }
  }

  tags = local.default_tags
}

# ============================================================================
# CodeBuild Project
# ============================================================================

# CodeBuild Projects (one per repo)
resource "aws_codebuild_project" "runner" {
  for_each = local.repos

  name                   = "${each.value.project_name}-${var.environment}-runner"
  description            = "GitHub Actions runner for ${var.github_owner}/${each.value.github_repository}"
  service_role           = aws_iam_role.codebuild.arn
  concurrent_build_limit = each.value.concurrent_build_limit

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = each.value.compute_type
    image                       = var.build_image
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    # Privileged mode: disabled when using Docker Server
    privileged_mode = !each.value.enable_docker_server && var.enable_docker

    environment_variable {
      name  = "GITHUB_OWNER"
      value = var.github_owner
    }

    environment_variable {
      name  = "GITHUB_REPOSITORY"
      value = each.value.github_repository
    }

    environment_variable {
      name  = "PROJECT_NAME"
      value = each.value.project_name
    }

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
    }

    # Docker Server fleet configuration (shared fleet)
    dynamic "fleet" {
      for_each = each.value.enable_docker_server ? [1] : []
      content {
        fleet_arn = aws_codebuild_fleet.docker_server[0].arn
      }
    }
  }

  source {
    type                = "GITHUB"
    location            = "https://github.com/${var.github_owner}/${each.value.github_repository}.git"
    git_clone_depth     = 1
    buildspec           = ""
    report_build_status = true

    git_submodules_config {
      fetch_submodules = false
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.runner[each.key].name
      status     = "ENABLED"
    }
  }

  dynamic "cache" {
    for_each = var.cache_type != "NO_CACHE" ? [1] : []
    content {
      type     = var.cache_type
      location = var.cache_type == "S3" ? "${aws_s3_bucket.cache[0].bucket}/cache" : null
      modes    = var.cache_type == "LOCAL" ? var.cache_modes : null
    }
  }

  # VPC configuration (only when NOT using Docker Server - fleet handles VPC in that case)
  dynamic "vpc_config" {
    for_each = var.enable_vpc && var.vpc_config != null && !each.value.enable_docker_server ? [var.vpc_config] : []
    content {
      vpc_id  = vpc_config.value.vpc_id
      subnets = vpc_config.value.subnet_ids
      security_group_ids = var.managed_security_groups ? [aws_security_group.codebuild_managed[0].id] : (
        length(vpc_config.value.security_group_ids) > 0 ? vpc_config.value.security_group_ids : [aws_security_group.codebuild_default[0].id]
      )
    }
  }

  tags = local.default_tags

  depends_on = [
    null_resource.import_credentials_pat,
    null_resource.import_credentials_github_app
  ]
}

# Webhooks for GitHub integration (one per repo, if not skipped)
resource "aws_codebuild_webhook" "runner" {
  for_each = { for k, v in local.repos : k => v if !v.skip_webhook_creation }

  project_name = aws_codebuild_project.runner[each.key].name
  build_type   = "BUILD"

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "WORKFLOW_JOB_QUEUED"
    }
  }
}

# Webhook verification removed - check webhooks_created output to see which repos have webhooks
