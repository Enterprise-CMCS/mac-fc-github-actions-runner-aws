locals {
  resource_prefix = "${var.project_name}-${var.environment}"

  # Get GitHub token from Secrets Manager or variable (for PAT auth only)
  github_token = var.auth_method == "pat" ? coalesce(
    var.github_token,
    var.github_secret_name != "" ? data.aws_secretsmanager_secret_version.github[0].secret_string : ""
  ) : ""

  # Determine GitHub connection ARN (for GitHub App auth)
  # Use provided ARN if available, otherwise use the created connection ARN
  github_connection_arn = var.auth_method == "github_app" ? coalesce(
    var.github_connection_arn,
    var.github_connection_name != "" ? aws_codeconnections_connection.github[0].arn : ""
  ) : ""

  # Determine if webhook can be created
  # User explicitly controls via skip_webhook_creation flag
  can_create_webhook = !var.skip_webhook_creation

  default_tags = merge(
    var.tags,
    {
      Module      = "terraform-aws-codebuild-github-runner"
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    }
  )
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

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
        echo "ERROR: GitHub secret '${var.github_secret_name}' not found!"
        echo ""
        echo "Create the secret with:"
        echo ""
        echo "aws secretsmanager create-secret \\"
        echo "  --name ${var.github_secret_name} \\"
        echo "  --description 'GitHub PAT for CodeBuild runner' \\"
        echo "  --secret-string 'ghp_your_actual_token_here' \\"
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
      echo "Secret '${var.github_secret_name}' found"
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

# S3 bucket for cache
resource "aws_s3_bucket" "cache" {
  count = var.cache_type == "S3" ? 1 : 0

  bucket        = "${local.resource_prefix}-runner-cache-${random_id.bucket_suffix.hex}"
  force_destroy = true

  tags = merge(local.default_tags, {
    Name = "${local.resource_prefix}-runner-cache"
  })
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

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "runner" {
  name              = "/aws/codebuild/${local.resource_prefix}-runner"
  retention_in_days = var.log_retention_days

  tags = local.default_tags

  # Wait for secret validation to pass (for PAT auth)
  depends_on = [null_resource.validate_secret]
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

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "Cleaning up GitHub credentials..."
      CRED_ARN=$(aws codebuild list-source-credentials \
        --region ${self.triggers.region} \
        --query "sourceCredentialsInfos[?serverType=='GITHUB'].arn | [0]" \
        --output text 2>/dev/null || echo "")

      if [ ! -z "$CRED_ARN" ] && [ "$CRED_ARN" != "None" ]; then
        aws codebuild delete-source-credentials --arn "$CRED_ARN" --region ${self.triggers.region} || true
      fi
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

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "Cleaning up GitHub credentials..."
      CRED_ARN=$(aws codebuild list-source-credentials \
        --region ${self.triggers.region} \
        --query "sourceCredentialsInfos[?serverType=='GITHUB'].arn | [0]" \
        --output text 2>/dev/null || echo "")

      if [ ! -z "$CRED_ARN" ] && [ "$CRED_ARN" != "None" ]; then
        aws codebuild delete-source-credentials --arn "$CRED_ARN" --region ${self.triggers.region} || true
      fi
    EOT
  }

  depends_on = [aws_codeconnections_connection.github]
}

# CodeBuild Project
resource "aws_codebuild_project" "runner" {
  name                   = "${local.resource_prefix}-runner"
  description            = "GitHub Actions runner for ${var.github_owner}/${var.github_repository}"
  service_role           = aws_iam_role.codebuild.arn
  concurrent_build_limit = var.concurrent_build_limit

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = var.compute_type
    image                       = var.build_image
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = var.enable_docker

    environment_variable {
      name  = "GITHUB_OWNER"
      value = var.github_owner
    }

    environment_variable {
      name  = "GITHUB_REPOSITORY"
      value = var.github_repository
    }

    environment_variable {
      name  = "PROJECT_NAME"
      value = var.project_name
    }

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
    }
  }

  source {
    type                = "GITHUB"
    location            = "https://github.com/${var.github_owner}/${var.github_repository}.git"
    git_clone_depth     = 1
    buildspec           = ""
    report_build_status = true

    git_submodules_config {
      fetch_submodules = false
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.runner.name
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

  dynamic "vpc_config" {
    for_each = var.enable_vpc && var.vpc_config != null ? [var.vpc_config] : []
    content {
      vpc_id             = vpc_config.value.vpc_id
      subnets            = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tags = local.default_tags

  depends_on = [
    null_resource.import_credentials_pat,
    null_resource.import_credentials_github_app
  ]
}

# Webhook for GitHub integration
# Only created when we have valid GitHub credentials (not placeholder)
resource "aws_codebuild_webhook" "runner" {
  count = local.can_create_webhook ? 1 : 0

  project_name = aws_codebuild_project.runner.name
  build_type   = "BUILD"

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "WORKFLOW_JOB_QUEUED"
    }
  }
}

# Verify webhook configuration (only if webhook was created)
resource "null_resource" "verify_webhook" {
  count = local.can_create_webhook ? 1 : 0

  triggers = {
    webhook_id = aws_codebuild_webhook.runner[0].id
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Verifying webhook configuration..."
      WEBHOOK_URL=$(aws codebuild batch-get-projects \
        --names ${aws_codebuild_project.runner.name} \
        --region ${data.aws_region.current.id} \
        --query "projects[0].webhook.url" \
        --output text 2>/dev/null || echo "")

      if [ ! -z "$WEBHOOK_URL" ] && [ "$WEBHOOK_URL" != "None" ]; then
        echo "Webhook configured: $WEBHOOK_URL"
      else
        echo "Warning: Webhook may not be properly configured"
      fi
    EOT
  }

  depends_on = [aws_codebuild_webhook.runner]
}
