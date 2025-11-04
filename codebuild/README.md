# terraform-aws-codebuild-github-runner

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
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

## 📊 Architecture

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

## 🔧 Requirements

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

## 🔐 Authentication Methods

This module supports two authentication methods:

| Method | Security | Setup Complexity | Token Lifetime | Recommended For |
|--------|----------|------------------|----------------|-----------------|
| **GitHub App** | Best | Medium (one-time manual step) | 1 hour (auto-refresh) | **Production** |
| **Personal Access Token** | Good | Low (fully automated) | 7-90 days (manual rotation) | Development/Testing |

### Why GitHub App?

- **24-720x shorter credential lifespan**: 1-hour tokens vs 7-90 day PATs
- **No user dependency**: Persists when employees leave
- **2.5-3x better API rate limits**: 12,500-15,000 vs 5,000 req/hr
- **Organization-level control**: Admins can manage and revoke access
- **Better audit trail**: GitHub App activity separate from user activity

## 🏃 Quick Start

Choose your authentication method below:

### Option A: GitHub App Authentication (Recommended for Production)

**Step 1: Create GitHub App** (One-time setup)

1. Go to GitHub Organization Settings → Developer settings → GitHub Apps → **New GitHub App**
2. Configure the app:
   - **Name**: `CodeBuild Runners` (or your choice)
   - **Homepage URL**: Your organization URL
   - **Webhook**: Uncheck "Active" (webhook handled by CodeBuild)
   - **Repository permissions**:
     - Administration: **Read and write**
     - Contents: **Read-only**
     - Metadata: **Read-only** (automatic)
   - **Organization permissions**:
     - Self-hosted runners: **Read and write**
3. Click **Create GitHub App**
4. Install the app on your organization or specific repositories

#### Step 2: Deploy the Runner (Module Creates Connection)

```hcl
module "github_runner" {
  source = "github.com/Enterprise-CMCS/terraform-aws-codebuild-github-runner"

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

**Step 3: Authorize Connection** (One-time manual step)

After `terraform apply`, the module output will show:

1. Direct link to AWS Console
2. Connection name and status
3. Step-by-step authorization instructions

Simply:

1. Click the console link
2. Find your connection (status: PENDING)
3. Click "Update pending connection"
4. Authorize with GitHub and select your GitHub App
5. Done! Connection status → AVAILABLE

#### Alternative: Use Existing Connection

If you already have an authorized CodeConnections connection:

```hcl
module "github_runner" {
  source = "github.com/Enterprise-CMCS/terraform-aws-codebuild-github-runner"

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

### Step 0: Get AWS credential from Kion/Cloudtamer

Get temporary AWS credential from Kion/Cloudtamer and run in on your terminal

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

cd test-module
cp terraform.tfvars.example terraform.tfvars

Update owner, repo, project name, environment and tags


### Step 4: Deploy

```bash
terraform init -upgrade
terraform plan
terraform apply
```

### Step 5: Test self-hosted runner with a wokflow file

Create a test github workflow file to test your self hosted runner. You can use the sample test-new-runner.yml file in the test-module directory.

NOTE: Don't forget to update your runs-on: with the output lable i.e. codebuild-demo-runner-dev-runner-${github.run_id}-${github.run_attempt}

```yaml

name: Test New CodeBuild Runner

on:
  workflow_dispatch:
  push:
    branches:
      - *
    paths:
      - 'test-module/**'
      - 'terraform-aws-codebuild-github-runner/**'

permissions:
  contents: read
  id-token: write

jobs:
  test-runner:
    name: Test New Runner
    runs-on: codebuild-demo-runner-dev-runner-${github.run_id}-${github.run_attempt}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Test AWS Credentials
        run: |
          echo "Testing AWS credentials..."
          aws sts get-caller-identity

      - name: Test Environment
        run: |
          echo "Testing runner environment..."
          echo "Runner: ${{ runner.name }}"
          echo "OS: ${{ runner.os }}"
          echo "Architecture: ${{ runner.arch }}"
          echo "Working Directory: $(pwd)"
          echo "User: $(whoami)"

      - name: Test Docker
        run: |
          echo "Testing Docker availability..."
          docker --version
          docker ps

      - name: Test AWS CLI
        run: |
          echo "AWS CLI Version:"
          aws --version
          echo ""
          echo "AWS Region:"
          echo $AWS_REGION
          echo ""
          echo "Caller Identity:"
          aws sts get-caller-identity --output json

      - name: Test Terraform
        run: |
          echo "Testing Terraform..."
          terraform version

      - name: Simple Build Test
        run: |
          echo "Running simple build test..."
          cd test-module
          echo "test" > test-file.txt
          cat test-file.txt

      - name: Summary
        if: always()
        run: |
          echo "## Test Runner Validation Complete!" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**Runner:** \`${{ runner.name }}\`" >> $GITHUB_STEP_SUMMARY
          echo "**Branch:** \`${{ github.ref_name }}\`" >> $GITHUB_STEP_SUMMARY
          echo "**Run ID:** \`${{ github.run_id }}\`" >> $GITHUB_STEP_SUMMARY
          echo "**Run Attempt:** \`${{ github.run_attempt }}\`" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "### Capabilities Verified:" >> $GITHUB_STEP_SUMMARY
          echo "- AWS credentials via IAM role" >> $GITHUB_STEP_SUMMARY
          echo "- Docker support" >> $GITHUB_STEP_SUMMARY
          echo "- Terraform CLI" >> $GITHUB_STEP_SUMMARY
          echo "- Basic file operations" >> $GITHUB_STEP_SUMMARY
```





**Alternative: If the secret already exists**, you can use a data source and skip the targeted apply:

```hcl
data "aws_secretsmanager_secret" "github_token" {
  name = "github/actions/runner-token"
}

module "github_runner" {
  source = "github.com/Enterprise-CMCS/terraform-aws-codebuild-github-runner"

  github_owner       = "your-org"
  github_repository  = "your-repo"
  github_secret_name = data.aws_secretsmanager_secret.github_token.name

  project_name = "my-project"
  environment  = "prod"
}
```

**Note for module consumers**: If you're creating the secret resource in your code and passing it to this module, you may need to add an explicit dependency:

```hcl
module "github_runner" {
  source = "github.com/Enterprise-CMCS/terraform-aws-codebuild-github-runner"

  # ... other variables ...

  depends_on = [aws_secretsmanager_secret.github_token]
}
```

### Using in GitHub Actions

```yaml
name: CI
on: [push, pull_request]

jobs:
  build:
    # Use the label from terraform output
    runs-on: codebuild-my-project-prod-runner-${{ github.run_id }}-${{ github.run_attempt }}

    steps:
      - uses: actions/checkout@v4

      - name: Run tests
        run: |
          echo "Running on CodeBuild!"
          aws sts get-caller-identity  # AWS credentials available!
```

## Inputs

### Required Variables

| Variable | Description | Type | Validation |
|----------|-------------|------|------------|
| `github_owner` | GitHub organization or username that owns the repository | `string` | N/A |
| `github_repository` | GitHub repository name where the runner will be registered | `string` | N/A |
| `project_name` | Name prefix for all AWS resources (used for naming consistency) | `string` | Must contain only lowercase letters, numbers, and hyphens |

### Authentication Variables

| Variable | Description | Type | Default | Notes |
|----------|-------------|------|---------|-------|
| `auth_method` | Authentication method | `string` | `"pat"` | `"pat"` for Personal Access Token or `"github_app"` for GitHub App |
| `github_connection_name` | Name for new CodeConnections connection | `string` | `""` | **Recommended**: Module creates connection for you |
| `github_connection_arn` | Existing CodeConnections connection ARN | `string` | `""` | Use if you already have an authorized connection |
| `github_secret_name` | AWS Secrets Manager secret name containing GitHub PAT as plaintext. Secret must exist before running terraform. Create with: aws secretsmanager create-secret --name `<name>` --secret-string 'ghp_token' | `string` | `""` | Required if `auth_method="pat"` |
| `github_token` | GitHub Personal Access Token (sensitive) | `string` | `""` | Only for development/testing with `auth_method="pat"` |
| `skip_webhook_creation` | Skip webhook creation (useful if you need to populate secret before creating webhook) | `bool` | `false` | For two-phase deployments |

> **GitHub App Authentication** (`auth_method="github_app"`):
>
> - **Option 1 (Recommended)**: Set `github_connection_name` - module creates connection, you authorize in console
> - **Option 2**: Set `github_connection_arn` - use your existing authorized connection
> - Most secure: 1-hour auto-refreshing tokens
> - One-time manual authorization in AWS Console
> - See [Authentication Methods](#-authentication-methods) for setup
>
> **PAT Authentication** (`auth_method="pat"`, default):
>
> - Requires GitHub token with scopes: `repo`, `admin:repo_hook`, `admin:org`
> - Store as plaintext in Secrets Manager (not JSON)
> - Token valid for 7-90 days (manual rotation required)

### Environment & Configuration

| Variable | Description | Type | Default | Valid Values |
|----------|-------------|------|---------|--------------|
| `environment` | Environment name for resource tagging and naming | `string` | `"dev"` | `dev`, `staging`, `prod` |
| `compute_type` | CodeBuild compute instance type | `string` | `"BUILD_GENERAL1_MEDIUM"` | See [Compute Types](#-compute-types) |
| `build_image` | Docker image for the CodeBuild environment | `string` | `"aws/codebuild/standard:7.0"` | Any valid CodeBuild image |
| `concurrent_build_limit` | Maximum number of concurrent builds allowed | `number` | `20` | 1-100 |
| `log_retention_days` | CloudWatch log retention period in days | `number` | `7` | 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653 |
| `enable_docker` | Enable Docker-in-Docker (privileged mode) | `bool` | `true` | N/A |

### Network & Security

| Variable | Description | Type | Default | Notes |
|----------|-------------|------|---------|-------|
| `enable_vpc` | Deploy CodeBuild runners within a VPC | `bool` | `false` | Requires `vpc_config` when `true` |
| `vpc_config` | VPC configuration object | `object` | `null` | Required when `enable_vpc = true` |

#### VPC Configuration Object

```hcl
vpc_config = {
  vpc_id             = string       # VPC ID where runners will be deployed
  subnet_ids         = list(string) # Private subnet IDs for runner placement
  security_group_ids = list(string) # Security group IDs for network access
}
```

### Caching & Performance

| Variable | Description | Type | Default | Valid Values |
|----------|-------------|------|---------|--------------|
| `cache_type` | Type of build cache to use | `string` | `"S3"` | `S3`, `LOCAL`, `NO_CACHE` |
| `cache_modes` | Cache modes for LOCAL cache type | `list(string)` | `["LOCAL_DOCKER_LAYER_CACHE", "LOCAL_SOURCE_CACHE"]` | Valid LOCAL cache modes |

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

## 📊 Compute Types

| Type | vCPUs | Memory | Cost/min |
|------|-------|--------|----------|
| `BUILD_GENERAL1_SMALL` | 2 | 3 GB | $0.003 |
| `BUILD_GENERAL1_MEDIUM` | 4 | 7 GB | $0.005 |
| `BUILD_GENERAL1_LARGE` | 8 | 15 GB | $0.010 |
| `BUILD_GENERAL1_XLARGE` | 36 | 72 GB | $0.034 |
| `BUILD_GENERAL1_2XLARGE` | 72 | 144 GB | $0.068 |

## 💰 Cost Comparison

| Runner Type | Cost per Minute | Monthly (1000 mins) |
|-------------|-----------------|---------------------|
| GitHub Hosted (Linux) | $0.008 | $8.00 |
| CodeBuild Small | $0.003 | $3.00 |
| CodeBuild Medium | $0.005 | $5.00 |
| CodeBuild Large | $0.010 | $10.00 |

## 📤 Outputs

### Primary Outputs

| Output | Description | Type | Usage |
|--------|-------------|------|-------|
| `runner_label` | Complete runner label for GitHub Actions workflows | `string` | Use directly in `runs-on:` |
| `project_name` | CodeBuild project name | `string` | For AWS CLI/API operations |
| `project_arn` | CodeBuild project ARN | `string` | For IAM policies and references |
| `service_role_arn` | CodeBuild service role ARN | `string` | For additional policy attachments |

### Connectivity Outputs

| Output | Description | Type | Sensitive | Usage |
|--------|-------------|------|-----------|-------|
| `webhook_url` | GitHub webhook URL | `string` | | GitHub webhook configuration |
| `webhook_payload_url` | Webhook payload URL | `string` | | Debugging webhook issues |
| `github_repository_url` | Full GitHub repository URL | `string` | | Documentation and linking |

### Infrastructure Outputs

| Output | Description | Type | Usage |
|--------|-------------|------|-------|
| `log_group` | CloudWatch log group name | `string` | Log monitoring and debugging |
| `cache_bucket` | S3 cache bucket name (if enabled) | `string` | Cache management and policies |
| `usage_instructions` | Formatted usage guide | `string` | Copy-paste workflow examples |

### Example Usage of Outputs

```hcl
module "github_runner" {
  source = "github.com/Enterprise-CMCS/terraform-aws-codebuild-github-runner"

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

# Output the runner label for workflows
output "runner_label" {
  description = "Use this label in your GitHub Actions workflows"
  value       = module.github_runner.runner_label
}

# Output instructions for team
output "setup_instructions" {
  description = "Instructions for using the runner"
  value       = module.github_runner.usage_instructions
}
```

## 🔒 Security

- **Ephemeral Runners**: Each job gets a fresh runner that's destroyed after use
- **IAM Roles**: Fine-grained AWS permissions per project
- **Secrets Manager**: Secure token storage with rotation support
- **VPC Support**: Optional network isolation
- **No Persistent State**: No data leakage between jobs

## Examples

### Basic Setup with PAT

```hcl
module "runner" {
  source = "github.com/Enterprise-CMCS/terraform-aws-codebuild-github-runner"

  github_owner       = "my-org"
  github_repository  = "my-repo"
  github_secret_name = "github/token"
  project_name       = "ci"
}
```

### With GitHub App (Production - Recommended)

```hcl
module "runner" {
  source = "github.com/Enterprise-CMCS/terraform-aws-codebuild-github-runner"

  # GitHub App authentication (module creates connection)
  auth_method            = "github_app"
  github_connection_name = "my-github-app"

  github_owner      = "my-org"
  github_repository = "my-repo"
  project_name      = "ci"
  environment       = "prod"
}

# Module outputs authorization instructions
output "setup_instructions" {
  value = module.runner.setup_complete
}
```

### With VPC

```hcl
module "runner" {
  source = "github.com/Enterprise-CMCS/terraform-aws-codebuild-github-runner"

  github_owner       = "my-org"
  github_repository  = "my-repo"
  github_secret_name = "github/token"
  project_name       = "ci"

  enable_vpc = true
  vpc_config = {
    vpc_id             = aws_vpc.main.id
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.runner.id]
  }
}
```

### High Performance

```hcl
module "runner" {
  source = "github.com/Enterprise-CMCS/terraform-aws-codebuild-github-runner"

  github_owner       = "my-org"
  github_repository  = "my-repo"
  github_secret_name = "github/token"
  project_name       = "ci"

  compute_type           = "BUILD_GENERAL1_LARGE"
  concurrent_build_limit = 50
}
```

## 🐛 Troubleshooting

### Common Issues

#### 1. Secret-Related Errors

**Error**: `Error retrieving secret: ResourceNotFoundException`

**Symptoms**: Terraform fails when trying to read the secret during apply
**Cause**: The secret doesn't exist yet, or the secret name is incorrect

**Note**: As of v1.1.0, the module includes **automatic secret validation** that checks if the secret exists before creating any infrastructure. If the secret is missing, you'll see a clear error message with instructions before any resources are created.

**Solutions**:

- Create the secret before running `terraform apply`:

  ```bash
  aws secretsmanager create-secret \
    --name "github/actions/runner-token" \
    --secret-string "ghp_your_actual_token_here"
  ```

- If you're creating the secret in Terraform, use targeted apply (see Step 3 in Quick Start)
- If using a data source, ensure the secret exists first
- Add explicit `depends_on` to the module if needed

**Error**: `Error creating CodeBuild webhook: InvalidInputException`

**Symptoms**: Webhook creation fails after applying Terraform
**Cause**: The secret value is still a placeholder or empty

**Solutions**:

- Update the secret value with your actual GitHub token:

  ```bash
  aws secretsmanager put-secret-value \
    --secret-id "github/actions/runner-token" \
    --secret-string "ghp_your_actual_token_here"
  ```

- Verify the token has the correct permissions (`repo`, `admin:repo_hook`, `admin:org`)
- Re-run `terraform apply` after updating the secret

**Error**: `Error: data source depends on resource that couldn't be found`

**Symptoms**: Terraform plan fails with dependency errors
**Cause**: The module tries to read the secret before it's created

**Solutions**:

- Use the recommended two-step apply process (see Step 3 in Quick Start)
- Add `depends_on = [aws_secretsmanager_secret.github_token]` to the module block
- Use a data source instead of creating the secret in the same apply

**Migrating from JSON to Plaintext format:**

If you previously used JSON format (`{"token":"value"}`), you need to update your secret:

```bash
# Option 1: Update via CLI
aws secretsmanager put-secret-value \
  --secret-id "github/actions/runner-token" \
  --secret-string "ghp_your_token_value_only"

# Option 2: Update via Console
# Navigate to Secrets Manager → Select secret → Retrieve secret value → Edit →
# Change from JSON to Plaintext and paste token directly
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

- Verify GitHub token has correct scopes (`repo`, `admin:repo_hook`, `admin:org`)
- For enterprise organizations, ensure SSO authorization is completed
- Check that webhook event type is `WORKFLOW_JOB_QUEUED`
- Confirm repository is not using shared VPC (not supported)

#### 2. VPC_CLIENT_ERROR: UnauthorizedOperation

**Symptoms**: Build fails during provisioning with VPC errors
**Diagnosis**:

```bash
# Check IAM role permissions
aws iam get-role-policy --role-name <codebuild-role-name> --policy-name <vpc-policy-name>
```

**Solutions**:

- Ensure CodeBuild service role has these permissions:

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

- Verify VPC is not shared VPC
- Ensure sufficient IP addresses available in subnets
- Confirm NAT gateway exists for internet access

#### 3. JIT Configuration Error

**Symptoms**: `RequestError: JIT configuration provided by GitHub is invalid`
**Causes**:

- GitHub token lacks required permissions
- Token not authorized for enterprise organization
- Repository webhook misconfigured

**Solutions**:

- Re-create GitHub token with all required scopes
- Complete SSO authorization for enterprise orgs
- Verify webhook points to correct CodeBuild project

#### 4. Build Timeouts

**Symptoms**: Builds timeout during execution
**Solutions**:

- Increase timeout in CodeBuild project settings
- Check network connectivity (VPC/NAT gateway)
- Verify Docker images are accessible
- Review CloudWatch logs for specific bottlenecks

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

- Check AWS credentials are valid
- Ensure correct AWS region is configured
- Verify IAM permissions for Terraform user/role

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

## 📜 License

Apache 2.0 - See [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

Built by the Enterprise-CMCS team for the community.

## References

- [AWS CodeBuild GitHub Actions](https://docs.aws.amazon.com/codebuild/latest/userguide/action-runner.html)
- [GitHub Self-Hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
