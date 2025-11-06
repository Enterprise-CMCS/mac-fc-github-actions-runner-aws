# github-actions-runner-aws

Terraform modules for creating self-hosted GitHub Actions runners on AWS.

## CodeBuild (Recommended)

The `codebuild/` module uses AWS CodeBuild for serverless, zero-maintenance GitHub Actions runners.

**Benefits:**
- Zero maintenance - no Docker images to update
- Serverless - no EC2 or ECS to manage
- Cost effective - ~40% savings vs GitHub-hosted runners
- AWS native - direct IAM role integration
- Secure - ephemeral runners with no persistent state

## Quick Start

### Prerequisites

- **AWS Credentials**: Get temporary AWS credentials from Kion/Cloudtamer and configure them in your terminal
- **Terraform** >= 1.0
- **GitHub App** installed (create CMS ticket) or Personal Access Token

### Step 1: Request GitHub App Access

Create a CMS ticket to install and enable the GitHub App for your repository.

### Step 2: Deploy with Terraform

```hcl
module "github_runner" {
  source = "github.com/Enterprise-CMCS/mac-fc-github-actions-runner-aws//codebuild?ref=v7.0.0"

  auth_method            = "github_app"
  github_connection_name = "my-github-connection"

  github_owner      = "your-org"
  github_repository = "your-repo"
  project_name      = "my-project"
  environment       = "dev"
}

output "setup_instructions" {
  value = module.github_runner.setup_complete
}
```

```bash
terraform init
terraform apply
```

### Step 3: Authorize Connection

After `terraform apply`, follow output instructions to authorize the connection in AWS Console.

### Step 4: Enable Webhook

Set `skip_webhook_creation = false` in your module and run:

```bash
terraform apply
```

### Step 5: Use in GitHub Actions

```yaml
name: CI
on: [push]

jobs:
  build:
    runs-on: codebuild-my-project-dev-runner-${{ github.run_id }}-${{ github.run_attempt }}
    steps:
      - uses: actions/checkout@v4
      - run: echo "Running on CodeBuild!"
```

## Alternative: Personal Access Token

If GitHub App is not available, you can use a Personal Access Token.

### Step 1: Create GitHub Token

Generate a PAT with scopes: `repo`, `admin:repo_hook`, `admin:org`

### Step 2: Store Token in AWS Secrets Manager

```bash
aws secretsmanager create-secret \
  --name "github/actions/runner-token" \
  --secret-string "ghp_your_token_here"
```

### Step 3: Deploy with Terraform

```hcl
module "github_runner" {
  source = "github.com/Enterprise-CMCS/mac-fc-github-actions-runner-aws//codebuild?ref=v7.0.0"

  auth_method        = "pat"
  github_secret_name = "github/actions/runner-token"

  github_owner      = "your-org"
  github_repository = "your-repo"
  project_name      = "my-project"
  environment       = "dev"
}
```

Follow Steps 4-5 from above to enable webhook and use in workflows.

## Full Documentation

See [codebuild/README.md](./codebuild/README.md) for:
- Detailed configuration options
- VPC configuration
- Docker support (privileged mode)
- Advanced examples
- Troubleshooting

## ECS [DEPRECATED]

The ECS-based runner is deprecated. See [Usage.md](./Usage.md) for legacy documentation.
