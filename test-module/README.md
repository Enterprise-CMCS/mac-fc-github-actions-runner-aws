# Test Module for CodeBuild GitHub Runner (PAT Auth)

Simple test module to validate the CodeBuild GitHub Runner module using PAT authentication.

## Quick Start

### Step 1: Get AWS credential from Kion/Cloudtamer

Get temporary AWS credential from Kion/Cloudtamer and run in on your terminal

### Step 2: Generate GitHub Token

Create new or update existing PAT with the following scopes:

- `repo` - Full control of repositories
- `admin:repo_hook` - Webhook management
- `admin:org` - Organization administration (for organization repositories)

### 3. Create Secret with your GitHub PAT

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


### 4. Go to test-module folder and Configure Variables

```bash
cd test-module
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 5. Initialize and Apply Terraform

```bash
terraform init
terraform apply
```

This creates:

- CodeBuild project
- IAM roles and policies
- CloudWatch log group
- S3 cache bucket


Now the CodeBuild webhook will be properly configured with your GitHub PAT.

## Testing

### Use in GitHub Actions Workflow

Create `.github/workflows/test.yml` and update the runs-on with the terraform ouput

```yaml
name: Test CodeBuild Runner
on: [push]

jobs:
  test:
    runs-on: codebuild-test-runner-dev-runner-${{ github.run_id }}-${{ github.run_attempt }}

    steps:
      - uses: actions/checkout@v4

      - name: Test runner
        run: |
          echo "Running on CodeBuild!"
          aws sts get-caller-identity

      - name: Run tests
        run: |
          echo "Your tests here"
```

### Check Logs

```bash
# Stream logs
aws logs tail /aws/codebuild/test-runner-dev-runner --follow

# List recent builds
aws codebuild list-builds-for-project --project-name test-runner-dev-runner

# Get build details
aws codebuild batch-get-builds --ids <build-id>
```

## Authentication Methods Tested

This test module uses **PAT (Personal Access Token)** authentication:

- Default authentication method
- Secret stored in AWS Secrets Manager (plaintext)
- No manual AWS Console steps required

## Cleanup

```bash
terraform destroy
```

## Module Source

Uses local module: `../terraform-aws-codebuild-github-runner`

This points to the module code on the current branch: `feat/github-app-authentication`
