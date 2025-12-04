# terraform-aws-codebuild-github-runner

[![Terraform](https://img.shields.io/badge/terraform-≥%201.0-623CE4.svg?style=flat)](https://www.terraform.io)

A Terraform module to create self-hosted GitHub Actions runners using AWS CodeBuild. Run your GitHub Actions workflows on AWS infrastructure with full control and cost savings.

## Features

- **Zero Maintenance**: Fully managed by AWS CodeBuild
- **Cost Effective**: ~40% cheaper than GitHub-hosted runners
- **Serverless**: No EC2 instances or Lambda functions to manage
- **Auto-scaling**: Runners created on-demand per job
- **AWS Native**: Direct IAM role integration for AWS services
- **Secure**: Ephemeral runners with no persistent state
- **Simple**: Just 3 required variables to get started
- **Docker Support**: Docker-in-Docker (privileged mode) or Docker Server (managed fleet)
- **Multi-Repository**: Deploy runners for multiple repos with shared infrastructure

## Architecture

```text
GitHub Repository
    ↓ (webhook on workflow_job event)
AWS CodeBuild
    ↓ (receives webhook)
JIT Runner Registration
    ↓ (registers ephemeral runner)
Execute GitHub Actions Job
    ↓
Report Results to GitHub
```

## Requirements

### Terraform Version

| Component | Version |
|-----------|---------|
| Terraform | `>= 1.0` |
| AWS Provider | `>= 5.0` |
| Null Provider | `>= 3.1` |
| Random Provider | `>= 3.1` |

### AWS Permissions

The following AWS permissions are required for the user/role running Terraform:

#### Core Permissions

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:CreateProject",
        "codebuild:UpdateProject",
        "codebuild:DeleteProject",
        "codebuild:CreateWebhook",
        "codebuild:DeleteWebhook",
        "codebuild:UpdateWebhook",
        "codebuild:ImportSourceCredentials",
        "codebuild:DeleteSourceCredentials",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:PassRole",
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:PutBucketPublicAccessBlock",
        "s3:PutBucketVersioning",
        "s3:PutEncryptionConfiguration",
        "logs:CreateLogGroup",
        "logs:DeleteLogGroup",
        "logs:PutRetentionPolicy",
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "*"
    }
  ]
}
```

#### VPC Permissions (when `enable_vpc = true`)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeVpcs",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupEgress"
      ],
      "Resource": "*"
    }
  ]
}
```

### GitHub Requirements

#### Option 1: GitHub App (Recommended for Production)

- GitHub App created in your organization
- AWS CodeConnections connection authorized
- Required GitHub App permissions:
  - Repository: Administration (Read & write)
  - Repository: Contents (Read-only)
  - Organization: Self-hosted runners (Read & write)

#### Option 2: Personal Access Token (PAT)

- PAT with the following scopes:
  - `repo` - Full control of repositories
  - `admin:repo_hook` - Webhook management
  - `admin:org` - Organization administration (for organization repositories)
- Repository Access:
  - Admin access to the target repository
  - Organization owner permissions (for organization repositories)

## Authentication Methods

This module supports two authentication methods:

| Method | Security | Setup Complexity | Token Lifetime | Recommended For |
|--------|----------|------------------|----------------|-----------------|
| **GitHub App** | ✅ Best | Medium (one-time manual step) | 1 hour (auto-refresh) | **Production** |
| **Personal Access Token** | ⚠️ Good | Low (fully automated) | 7-90 days (manual rotation) | Development/Testing |

### Why GitHub App?

- **No user dependency**: Persists when employees leave
- **Organization-level control**: Admins can manage and revoke access
- **Better audit trail**: GitHub App activity separate from user activity
- **Shorter token lifetime**: 1-hour auto-refreshing tokens vs 7-90 day PATs

## Quick Start

Choose your authentication method below:

### Option A: GitHub App Authentication (Recommended for Production)

**Prerequisites:**

- GitHub App installed in your organization (create CMS ticket)
- Required permissions: Repository Administration (Read & write), Contents (Read-only), Organization Self-hosted runners (Read & write)

**Deploy with Terraform:**

```hcl
module "github_runner" {
  source = "github.com/Enterprise-CMCS/mac-fc-github-actions-runner-aws//codebuild?ref=v7.0.0"

  # GitHub App authentication (module creates the connection!)
  auth_method            = "github_app"
  github_connection_name = "github-codebuild-runners"

  # Repository configuration
  github_owner      = "your-org"
  github_repository = "your-repo"
  project_name      = "my-project"
  environment       = "prod"

  tags = {
    Team = "DevOps"
  }
}

# Module outputs authorization instructions
output "setup_instructions" {
  value = module.github_runner.setup_complete
}
```

**Authorize Connection:**

After `terraform apply`, follow the instructions in the `setup_complete` output to authorize the connection in AWS Console.

#### Alternative: Use Existing Connection

If you already have an authorized CodeConnections connection:

```hcl
module "github_runner" {
  source = "github.com/Enterprise-CMCS/mac-fc-github-actions-runner-aws//codebuild?ref=v7.0.0"

  # Use existing connection
  auth_method           = "github_app"
  github_connection_arn = "arn:aws:codeconnections:us-east-1:123456789:connection/abc-123"

  github_owner      = "your-org"
  github_repository = "your-repo"
  project_name      = "my-project"
  environment       = "prod"
}
```



### Option B: Personal Access Token (PAT) Authentication

### Prerequisites

Get temporary AWS credentials from Kion/Cloudtamer and configure them in your terminal.

### Step 1: Generate GitHub Token

Create new or update existing PAT with the following scopes:

- `repo` - Full control of repositories
- `admin:repo_hook` - Webhook management
- `admin:org` - Organization administration (for organization repositories)

### Step 2: Create AWS Secret

```bash
# Create secret with placeholder value first
aws secretsmanager create-secret \
  --name "github/actions/runner-token" \
  --secret-string "placeholder"

# Update with actual token value (keep token secure, don't store in shell history)
aws secretsmanager put-secret-value \
  --secret-id "github/actions/runner-token" \
  --secret-string "ghp_your_actual_token_here"
```

### Step 3: update terraform.tfvars

```bash
cd examples/basic
cp terraform.tfvars.example terraform.tfvars
```

Update owner, repo, project name, environment and tags.


### Step 4: Deploy

```bash
terraform init -upgrade
terraform plan
terraform apply
```

### Step 5: Test self-hosted runner with a workflow file

Create a minimal GitHub workflow to validate the runner. Use the label printed by Terraform output `runner_label` (example pattern: `codebuild-<project>-<env>-runner-${{ github.run_id }}-${{ github.run_attempt }}`).

```yaml
name: Test CodeBuild Runner

on:
  workflow_dispatch:

jobs:
  test-runner:
    name: Test Runner
    runs-on: codebuild-demo-dev-runner-${{ github.run_id }}-${{ github.run_attempt }}
    steps:
      - uses: actions/checkout@v4

      - name: Show environment
        run: |
          echo "Runner: ${{ runner.name }}"
          echo "OS: ${{ runner.os }}"
          echo "Arch: ${{ runner.arch }}"
          pwd && whoami

      - name: Check AWS identity
        run: aws sts get-caller-identity

      - name: Optional: check Docker (enable_docker must be true)
        run: docker --version || true
```






## Inputs

### Required Variables

| Variable | Description | Type | Validation |
|----------|-------------|------|------------|
| `github_owner` | GitHub organization or username that owns the repository | `string` | N/A |
| `github_repository` | GitHub repository name where the runner will be registered | `string` | N/A (ignored if `repositories` provided) |
| `project_name` | Name prefix for all AWS resources (used for naming consistency) | `string` | Must contain only lowercase letters, numbers, and hyphens (ignored if `repositories` provided) |

### Multi-Repository Configuration

| Variable | Description | Type | Default |
|----------|-------------|------|---------|
| `repositories` | Map of repositories to create runners for. Module creates shared S3, security group, and Docker fleet. | `map(object)` | `{}` |

**repositories object structure:**

```hcl
repositories = {
  "repo-key" = {
    github_repository      = string                    # Required
    project_name          = string                    # Required
    compute_type          = optional(string)          # Default: BUILD_GENERAL1_MEDIUM
    concurrent_build_limit = optional(number)          # Default: 20
    skip_webhook_creation  = optional(bool)           # Default: true
    enable_docker_server   = optional(bool)           # Default: false
  }
}
```

**Note:** `project_name` must contain only lowercase letters, numbers, and hyphens.

### Authentication Variables

| Variable | Description | Type | Default | Notes |
|----------|-------------|------|---------|-------|
| `auth_method` | Authentication method | `string` | `"github_app"` | `"pat"` for Personal Access Token or `"github_app"` for GitHub App |
| `github_connection_name` | Name for new CodeConnections connection | `string` | `""` | **Recommended**: Module creates connection for you |
| `github_connection_arn` | Existing CodeConnections connection ARN | `string` | `""` | Use if you already have an authorized connection |
| `github_secret_name` | AWS Secrets Manager secret name containing GitHub PAT as plaintext. Secret must exist before running terraform. Create with: aws secretsmanager create-secret --name [name] --secret-string 'ghp_token' | `string` | `""` | Required if `auth_method="pat"` |
| `github_token` | GitHub Personal Access Token (sensitive) | `string` | `""` | Only for development/testing with `auth_method="pat"` |
| `skip_webhook_creation` | Skip webhook creation (useful if you need to populate secret before creating webhook) | `bool` | `true` | For two-phase deployments |

> **GitHub App Authentication** (`auth_method="github_app"`):
>
> - **Option 1 (Recommended)**: Set `github_connection_name` - module creates connection, you authorize in console
> - **Option 2**: Set `github_connection_arn` - use your existing authorized connection
> - Most secure: 1-hour auto-refreshing tokens
> - One-time manual authorization in AWS Console
> - See [Authentication Methods](#authentication-methods) for setup
>
> **PAT Authentication** (`auth_method="pat"`):
>
> - Requires GitHub token with scopes: `repo`, `admin:repo_hook`, `admin:org`
> - Store as plaintext in Secrets Manager (not JSON)
> - Token valid for 7-90 days (manual rotation required)

### Environment & Configuration

| Variable | Description | Type | Default | Valid Values |
|----------|-------------|------|---------|--------------|
| `environment` | Environment name for resource tagging and naming | `string` | `"dev"` | `dev`, `staging`, `prod` |
| `compute_type` | CodeBuild compute instance type | `string` | `"BUILD_GENERAL1_MEDIUM"` | See [Compute Types](#compute-types) |
| `build_image` | Docker image for the CodeBuild environment | `string` | `"aws/codebuild/standard:7.0"` | Any valid CodeBuild image |
| `concurrent_build_limit` | Maximum number of concurrent builds allowed | `number` | `20` | 1-100 |
| `log_retention_days` | CloudWatch log retention period in days | `number` | `7` | 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653 |

### Docker Configuration

| Variable | Description | Type | Default | Notes |
|----------|-------------|------|---------|-------|
| `enable_docker` | Enable Docker-in-Docker (privileged mode) | `bool` | `true` | Traditional Docker support, uses privileged mode |
| `enable_docker_server` | Enable Docker Server mode (alternative to DinD) | `bool` | `false` | Uses LINUX_EC2 fleet, no privileged mode required. Cannot be used with `enable_docker=true` |
| `docker_server_capacity` | Base capacity for Docker server fleet | `number` | `1` | Number of Docker daemon instances (1-100). Only used when `enable_docker_server=true` |
| `docker_server_compute_type` | Compute type for Docker server fleet | `string` | `"BUILD_GENERAL1_SMALL"` | SMALL, MEDIUM, or LARGE. Only used when `enable_docker_server=true` |
| `docker_server_subnet_id` | Single subnet ID for Docker Server fleet | `string` | `""` | Fleet supports only ONE subnet. If empty, uses first subnet from `vpc_config.subnet_ids` |

**Docker Modes:**

- **Docker-in-Docker (DinD)**: Traditional approach using privileged mode. Simpler setup, runs directly on project instance.
- **Docker Server**: Managed LINUX_EC2 fleet providing Docker daemon. No privileged mode required, better for VPC environments. Requires `build_image = "aws/codebuild/standard:7.0"` or later.

**Security Note:** CodeBuild provides VM-level isolation. Each build runs on single-tenant EC2 instances. See [AWS Security Documentation](https://docs.aws.amazon.com/codebuild/latest/userguide/security.html) for details.

#### Docker Server Example

To use Docker Server mode instead of traditional Docker-in-Docker:

```hcl
module "github_runner" {
  source = "github.com/Enterprise-CMCS/mac-fc-github-actions-runner-aws//codebuild?ref=v7.1.0"

  # Authentication
  auth_method            = "github_app"
  github_connection_name = "my-connection"

  # Repository
  github_owner      = "your-org"
  github_repository = "your-repo"
  project_name      = "my-project"

  # Docker Server Configuration
  build_image          = "aws/codebuild/standard:7.0"  # Required: 7.0+
  enable_docker        = false                          # Disable DinD
  enable_docker_server = true                           # Enable Docker Server

  # Docker Server Fleet Settings
  docker_server_capacity     = 1                        # Base capacity (always-on)
  docker_server_compute_type = "BUILD_GENERAL1_SMALL"   # Fleet instance size

  # VPC Configuration (required for Docker Server)
  enable_vpc = true
  vpc_config = {
    vpc_id             = "vpc-xxxxx"
    subnet_ids         = ["subnet-xxxxx", "subnet-yyyyy"]
    security_group_ids = []  # Use managed security groups
  }
}
```

### Multi-Repository Deployment

Deploy runners for multiple repositories with shared infrastructure:

```hcl
module "github_runners" {
  source = "github.com/Enterprise-CMCS/mac-fc-github-actions-runner-aws//codebuild?ref=v7.2.0"

  auth_method            = "github_app"
  github_connection_name = "my-github-connection"
  github_owner           = "your-org"
  environment            = "prod"

  repositories = {
    "repo-1" = {
      github_repository      = "repo-1"
      project_name           = "repo1-runner"
      compute_type           = "BUILD_GENERAL1_MEDIUM"
      concurrent_build_limit = 20
      skip_webhook_creation  = false
      enable_docker_server   = true
    }
    "repo-2" = {
      github_repository      = "repo-2"
      project_name           = "repo2-runner"
      skip_webhook_creation  = false
      enable_docker_server   = true
    }
  }

  # Shared fleet configuration
  docker_server_capacity     = 2
  docker_server_compute_type = "BUILD_GENERAL1_SMALL"

  # Shared VPC
  enable_vpc = true
  vpc_config = {
    vpc_id             = "vpc-xxxxx"
    subnet_ids         = ["subnet-xxxxx"]
    security_group_ids = []
  }
}
```

**Shared (1 total):** S3 bucket, security group, Docker fleet, IAM roles
**Per-repo (N total):** CodeBuild project, log group, webhook

Each repository uses its own runner label. Access via `runner_labels` output map.

### Network & Security

| Variable | Description | Type | Default | Notes |
|----------|-------------|------|---------|-------|
| `enable_vpc` | Deploy CodeBuild runners within a VPC | `bool` | `true` | Requires `vpc_config` when `true` |
| `vpc_config` | VPC configuration object | `object` | `null` | Required when `enable_vpc = true` |
| `managed_security_groups` | Create managed security groups | `bool` | `true` | Auto-creates security groups when enabled |

#### VPC Configuration Object

```hcl
vpc_config = {
  vpc_id             = string       # VPC ID where runners will be deployed
  subnet_ids         = list(string) # Private subnet IDs for runner placement
  security_group_ids = list(string) # Security group IDs (can be empty list [])
}
```

### Caching & Performance

| Variable | Description | Type | Default | Valid Values |
|----------|-------------|------|---------|--------------|
| `cache_type` | Type of build cache to use | `string` | `"S3"` | `S3`, `LOCAL`, `NO_CACHE` |
| `cache_modes` | Cache modes for LOCAL cache type | `list(string)` | `["LOCAL_DOCKER_LAYER_CACHE", "LOCAL_SOURCE_CACHE"]` | Valid LOCAL cache modes |
| `s3_cache_sse_mode` | S3 cache encryption mode | `string` | `"SSE_S3"` | `SSE_S3` or `SSE_KMS` |
| `s3_cache_kms_key_arn` | KMS key for S3 cache (when SSE_KMS) | `string` | `""` | If empty and SSE_KMS, module creates a key |
| `s3_cache_enable_versioning` | Enable S3 versioning on cache bucket | `bool` | `false` | Optional; may increase cost |

### Resource Tagging

| Variable | Description | Type | Default | Notes |
|----------|-------------|------|---------|-------|
| `tags` | Additional tags to apply to all resources | `map(string)` | `{}` | Merged with default tags |

> **Default Tags**: The module automatically applies these tags:
>
> - `Module: terraform-aws-codebuild-github-runner`
> - `Environment: <environment>`
> - `Project: <project_name>`
> - `ManagedBy: Terraform`

## Compute Types

| Type | vCPUs | Memory | Cost/min |
|------|-------|--------|----------|
| `BUILD_GENERAL1_SMALL` | 2 | 3 GB | $0.003 |
| `BUILD_GENERAL1_MEDIUM` | 4 | 7 GB | $0.005 |
| `BUILD_GENERAL1_LARGE` | 8 | 15 GB | $0.010 |
| `BUILD_GENERAL1_XLARGE` | 36 | 72 GB | $0.034 |
| `BUILD_GENERAL1_2XLARGE` | 72 | 144 GB | $0.068 |

## Security Options

- CloudWatch Logs KMS: set `cloudwatch_kms_key_arn` to encrypt log events with your KMS key.
- S3 TLS-only access: enforced by default via bucket policy when `cache_type = "S3"`.
- S3 encryption: `s3_cache_sse_mode` defaults to `SSE_S3`; set to `SSE_KMS` and optionally supply `s3_cache_kms_key_arn` to use a customer-managed key.
- Managed Security Groups: set `managed_security_groups = true` (with `enable_vpc = true`) to auto-create security groups for the CodeBuild project.

## Cost Comparison

| Runner Type | Cost per Minute | Monthly (1000 mins) |
|-------------|-----------------|---------------------|
| GitHub Hosted (Linux) | $0.008 | $8.00 |
| CodeBuild Small | $0.003 | $3.00 |
| CodeBuild Medium | $0.005 | $5.00 |
| CodeBuild Large | $0.010 | $10.00 |

## Outputs

### Primary Outputs

| Output | Description | Type | Usage |
|--------|-------------|------|-------|
| `runner_labels` | Runner labels for GitHub Actions workflows | `map(string)` | Multi-repo: map of repo-key => label. Single-repo: map with one entry |
| `project_names` | CodeBuild project names | `map(string)` | Multi-repo: map of repo-key => name. Single-repo: map with one entry |
| `project_arns` | CodeBuild project ARNs | `map(string)` | Multi-repo: map of repo-key => ARN. Single-repo: map with one entry |
| `service_role_arn` | CodeBuild service role ARN | `string` | For additional policy attachments |

### Connectivity Outputs

| Output | Description | Type | Sensitive | Usage |
|--------|-------------|------|-----------|-------|
| `github_repository_urls` | Full GitHub repository URLs | `map(string)` | ❌ | Multi-repo: map of repo-key => URL. Single-repo: map with one entry |

### Infrastructure Outputs

| Output | Description | Type | Usage |
|--------|-------------|------|-------|
| `log_groups` | CloudWatch log group names | `map(string)` | Multi-repo: map of repo-key => log-group. Single-repo: map with one entry |
| `cache_bucket` | S3 cache bucket name (if enabled) | `string` | Cache management and policies |
| `codebuild_security_group_id` | CodeBuild project security group ID | `string` | Grant CodeBuild access to RDS/Redshift/ElastiCache |
| `webhooks_created` | Webhook creation status per repo | `map(bool)` | Multi-repo: map of repo-key => created. Single-repo: map with one entry |
| `usage_instructions` | Formatted usage guide | `string` | Copy-paste workflow examples |

### Example Usage of Outputs

```hcl
module "github_runner" {
  source = "github.com/Enterprise-CMCS/mac-fc-github-actions-runner-aws//codebuild?ref=v7.0.0"

  github_owner       = "my-org"
  github_repository  = "my-repo"
  github_secret_name = "github/token"
  project_name       = "ci"
}

# Use outputs for additional configuration
resource "aws_iam_role_policy" "additional_permissions" {
  name = "additional-permissions"
  role = basename(module.github_runner.service_role_arn)

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject"
      ]
      Resource = "arn:aws:s3:::my-bucket/*"
    }]
  })
}

# Output runner labels (map for multi-repo)
output "runner_labels" {
  description = "Use these labels in your GitHub Actions workflows"
  value       = module.github_runner.runner_labels
}

# Access specific repo label
output "repo1_label" {
  value = module.github_runner.runner_labels["repo-1"]
}

# Output instructions for team
output "setup_instructions" {
  description = "Instructions for using the runner"
  value       = module.github_runner.usage_instructions
}

# Grant CodeBuild access to Redshift
resource "aws_security_group_rule" "codebuild_to_redshift" {
  type                     = "ingress"
  from_port                = 5439
  to_port                  = 5439
  protocol                 = "tcp"
  source_security_group_id = module.github_runner.codebuild_security_group_id
  security_group_id        = aws_redshift_cluster.example.vpc_security_group_ids[0]
  description              = "Allow CodeBuild runner access to Redshift"
}
```

## Security

- **Ephemeral Runners**: Each job gets a fresh runner that's destroyed after use
- **IAM Roles**: Fine-grained AWS permissions per project
- **Secrets Manager**: Secure token storage with rotation support
- **VPC Support**: Optional network isolation
- **No Persistent State**: No data leakage between jobs


## Troubleshooting

### Common Issues

#### 1. Secret-Related Errors

**Common secret errors and solutions:**

**Secret doesn't exist:**

```bash
# Create the secret before running terraform apply
aws secretsmanager create-secret \
  --name "github/actions/runner-token" \
  --secret-string "ghp_your_actual_token_here"
```

**Invalid token or webhook creation fails:**

```bash
# Update secret with valid token
aws secretsmanager put-secret-value \
  --secret-id "github/actions/runner-token" \
  --secret-string "ghp_your_actual_token_here"
```

Verify token has required scopes: `repo`, `admin:repo_hook`, `admin:org`

**Terraform dependency errors:**

Add explicit dependency if creating secret in same terraform apply:

```hcl
module "github_runner" {
  # ... configuration ...
  depends_on = [aws_secretsmanager_secret.github_token]
}
```

#### 2. Runner Not Picking Up Jobs

**Symptoms**: GitHub Actions jobs remain queued, never start

**Diagnosis**:

```bash
# Check webhook registration
aws codebuild batch-get-projects --names <project-name> --query "projects[0].webhook"

# Check recent builds
aws codebuild list-builds-for-project --project-name <project-name>
```

**Solutions**:

- ✅ Verify GitHub token has correct scopes (`repo`, `admin:repo_hook`, `admin:org`)
- ✅ For enterprise organizations, ensure SSO authorization is completed
- ✅ Check that webhook event type is `WORKFLOW_JOB_QUEUED`
- ✅ Confirm repository is not using shared VPC (not supported)

#### 2. VPC_CLIENT_ERROR: UnauthorizedOperation

**Symptoms**: Build fails during provisioning with VPC errors

**Diagnosis**:

```bash
# Check IAM role permissions
aws iam get-role-policy --role-name <codebuild-role-name> --policy-name <vpc-policy-name>
```

**Solutions**:

- ✅ Ensure CodeBuild service role has these permissions:

  ```json
  {
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": [
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
      ],
      "Resource": "*"
    }]
  }
  ```

- ✅ Verify VPC is not shared VPC
- ✅ Ensure sufficient IP addresses available in subnets
- ✅ Confirm NAT gateway exists for internet access

#### 3. JIT Configuration Error

**Symptoms**: `RequestError: JIT configuration provided by GitHub is invalid`

**Causes**:

- GitHub token lacks required permissions
- Token not authorized for enterprise organization
- Repository webhook misconfigured

**Solutions**:

- ✅ Re-create GitHub token with all required scopes
- ✅ Complete SSO authorization for enterprise orgs
- ✅ Verify webhook points to correct CodeBuild project

#### 4. Build Timeouts

**Symptoms**: Builds timeout during execution

**Solutions**:

- ✅ Increase timeout in CodeBuild project settings
- ✅ Check network connectivity (VPC/NAT gateway)
- ✅ Verify Docker images are accessible
- ✅ Review CloudWatch logs for specific bottlenecks

#### 5. Terraform Errors

**Error**: `Module source has changed`

**Solution**:

```bash
terraform init -upgrade
terraform plan
terraform apply
```

**Error**: `InvalidClientTokenId: The security token included in the request is invalid`

**Solution**:

- ✅ Check AWS credentials are valid
- ✅ Ensure correct AWS region is configured
- ✅ Verify IAM permissions for Terraform user/role

### Debugging Commands

#### Check Build Status

```bash
# List recent builds
aws codebuild list-builds-for-project --project-name <project-name>

# Get build details
aws codebuild batch-get-builds --ids <build-id>

# Stream logs
aws logs tail /aws/codebuild/<project-name> --follow
```

#### Validate Configuration

```bash
# Check webhook status
aws codebuild batch-get-projects --names <project-name> \
  --query "projects[0].webhook.{url:url,payloadUrl:payloadUrl}"

# Verify IAM role
aws iam get-role --role-name <role-name>
aws iam list-attached-role-policies --role-name <role-name>
aws iam list-role-policies --role-name <role-name>
```

#### Network Troubleshooting (VPC)

```bash
# Check VPC configuration
aws ec2 describe-vpcs --vpc-ids <vpc-id>
aws ec2 describe-subnets --subnet-ids <subnet-id>
aws ec2 describe-security-groups --group-ids <sg-id>

# Verify NAT gateway
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=<vpc-id>"
```

### Getting Help

1. **Check CloudWatch Logs**: Most issues are logged in detail
2. **Enable Debug Logging**: Add environment variables to buildspec
3. **Review GitHub Actions Logs**: Check both GitHub and AWS logs
4. **Test Manually**: Use AWS CLI to trigger builds manually

#### Manual Build Test

```bash
aws codebuild start-build --project-name <project-name>
```

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Submit a pull request


## Acknowledgments

Built by mac-fc-embedded team for Enterprise CMS teams.

## References

- [AWS CodeBuild GitHub Actions](https://docs.aws.amazon.com/codebuild/latest/userguide/action-runner.html)
- [GitHub Self-Hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
