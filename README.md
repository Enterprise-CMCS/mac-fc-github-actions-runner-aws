# github-actions-runner-aws

## About

This repository contains the Dockerfile for a self-hosted GitHub Actions runner and an associated Terraform module which can be run in your environment to provision:

* An ECR repository to which you can push images of your runner
* An ECS cluster and ECS Fargate task definition to spin up an instance of this runner *per job* in your GitHub Actions workflow.

![AWS Deployment Diagram](./AWSDeploymentDiagram.png)

## Set Up

1. Fork this repository.
2. Set up an IAM user in AWS with the necessary permissions to support the docker-build.yml workflow script included. See `IAM User Permissions` section below for details.
    * Once you have your user, be sure to populate your repository secrets with its access keys
    * Refer to the [docs](docs) for past ADRs regarding the IAM user and GitHub actions workflow considerations. In particular, you will need to manually change your ECR repository name.
3. Provision the Terraform module in this repository.
4. You should now be able to push images to your ECR repository via a push to your main branch or a new release. An ECS Cluster and Service should also be set up for you.
5. See the [documentation](Usage.md) on usage of the runner on how to deploy runners to your service.

### IAM User Permissions

Creation of the IAM user, group, and attached policy should be submitted via [CMS Jira](https://jiraent.cms.gov/) to the Cloud Support team.

For the IAM user needed for Github to interact with AWS (specifically ECR and ECS), the username should be `github-runner` and the user should be a part of the group `github-runner-group`. The permissions policy should be attached to that group `github-runner-group` to follow [best practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html#use-groups-for-permissions).

`$AWS_ACCOUNT_ID` and `$AWS_REGION` in the IAM policy should be updated to be the appropriate account ID and region for your deployment.

All of the specified resources in the IAM policy do not have to exist prior to the policy being created.

`github-runners` IAM policy:

```text
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "IAMActions",
            "Effect": "Allow",
            "Action": [
                "iam:GetRole",
                "iam:PassRole"
            ],
            "Resource": "arn:aws:iam::$AWS_ACCOUNT_ID:role/ecs-task-role-*"
        },
        {
            "Sid": "ECRTokenAndECSTaskActions",
            "Effect": "Allow",
            "Action": [
                "ecs:RegisterTaskDefinition",
                "ecr:GetAuthorizationToken",
                "ecs:DescribeTaskDefinition"
            ],
            "Resource": "*"
        },
        {
            "Sid": "ECSClusterActions",
            "Effect": "Allow",
            "Action": [
                "ecs:DescribeServices",
                "ecs:UpdateService"
            ],
            "Resource": [
                "arn:aws:ecs:$AWS_REGION:$AWS_ACCOUNT_ID:cluster/github-runner",
                "arn:aws:ecs:$AWS_REGION:$AWS_ACCOUNT_ID:service/github-runner/github-actions-runner"
            ]
        }
    ]
}
```

## Local Usage

1. Clone this repository to your machine.
2. Ensure your environment variables are populated:
    * `PERSONAL_ACCESS_TOKEN` - Your github personal access token with repository permissions.
        * Go to Settings > Developer Settings > Personal Access Token, and click on **Generate new token**
        ![Where to Generate a New Token](./GitHubPAT.png)
        * Give your token a note and check the box to give full control of private repositories
        ![Repository Permissions](./GitHubPAT2.png)
        * Once generated, be sure to save your token in a secure location such as 1pass or AWS Secrets Manager
    * `REPO_OWNER` - The name of the repository owner, e.g. `CMSgov`
    * `REPO_NAME` - The name of the repository
3. Build and run the image. `./entrypoint.sh` should register the runner with your repository and start listening for jobs.
4. In one of the workflows in the target repository, change the `runs-on` value to `self-hosted`. This will make the workflow use the registered self-hosted runner to complete its task, after which it will shut down.

## Terraform Module

This repository contains a Terraform module to deploy an ECR repo, ECS cluster, and ECS service in support of automating deployment of ephemeral self-hosted Github Actions runners within AWS.

This module supports the following features:

* Optionally pass an existing ECS Cluster, and if not, create one
* Set default desired count for ECS Service (default is 0, assuming it will be managed by Github Actions workflow)

### Usage

```hcl
module "github-actions-runner-aws" {
  source = "github.com/cmsgov/github-actions-runner-aws?ref=v2.0.0"

  # ECS variables
  environment               = "dev"
  ecs_desired_count         = 0
  ecs_vpc_id                = "${vpc.id}"
  ecs_subnet_ids            = "${vpc.private_subnets.id}"
  logs_cloudwatch_group_arn = "${cloudwatch_group_arn.arn}"

  # GitHub Runner variables
  personal_access_token_arn = "${secretsmanager.token.arn}"
  github_repo_owner         = "${repo_owner}"
  github_repo_name          = "${repo_name}"
}
```

### Data Sources

Some existing variable information can be looked-up in AWS via data sources. For example:

```hcl
data "aws_secretsmanager_secret_version" "token" {
  secret_id = "/github-runner-dev/token"
}
```

Will let you then use the ARN of that data source in this way:

```hcl
personal_access_token_arn = data.aws_secretsmanager_secret_version.token.arn
```

### Required Parameters

| Name | Description |
|------|---------|
| ci_user_arn | ARN for CI user which has read/write permissions |
| environment | Environment name (used in naming resources) |
| ecs_desired_count | Sets the default desired count for task definitions within the ECS service |
| ecs_vpc_id | VPC ID to be used by ECS |
| ecs_subnet_ids | Subnet IDs for the ECS tasks. |
| logs_cloudwatch_group_arn | CloudWatch log group ARN for container logs |
| personal_access_token_arn | AWS SecretsManager ARN for GitHub personal access token |
| github_repo_owner | The name of the Github repo owner |
| github_repo_name | The Github repository name |

### Optional Parameters

| Name | Default Value | Description |
|------|---------|---------|
| ecr_repo_tag | "latest" | The tag to identify and pull the image in ECR repo |
| ecs_cluster_arn | "" | ECS cluster ARN to use for running this profile |
| github_repo_owner | "CMSgov" | The name of the Github repo owner. |
| tags | {} | Additional tags to apply |

### Outputs

None.

### Requirements

| Name | Version |
|------|---------|
| terraform | >= 0.13 |
| aws | >= 3.0 |

### Modules

None.
