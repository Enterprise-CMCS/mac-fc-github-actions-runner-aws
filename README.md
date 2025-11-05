# github-actions-runner-aws

This repo contains Terraform modules for creating self-hosted GitHub Actions runners on AWS.

## CodeBuild (Recommended)

The `codebuild/` module is the **recommended approach** for self-hosted GitHub Actions runners on AWS.

### Why CodeBuild?

- **Zero Maintenance**: No Docker images to maintain or update
- **Serverless**: No ECS clusters or tasks to manage
- **Cost-Effective**: ~40% savings vs GitHub-hosted runners, pay per build minute
- **AWS Native**: Direct IAM role integration, no credential management
- **Secure**: Ephemeral runners with no persistent state

### Get Started

For complete instructions, examples, and troubleshooting, see **[codebuild/README.md](./codebuild/README.md)**.

## ECS [DEPRECATED]

The ECS-based runner implementation is deprecated in favor of the CodeBuild module above.

For legacy documentation, see **[github-actions-runner-terraform/README.md](./github-actions-runner-terraform/README.md)**.
