# github-actions-runner-aws

## About
This repository contains the Dockerfile for a self-hosted GitHub Actions runner and an associated Terraform module which can be run in your environment to provision:
* An ECR repository to which you can push images of your runner
* **(WIP)** An ECS cluster and ECS Fargate task definition to spin up an instance of this runner *per job* in your GitHub Actions workflow.

## Set Up
1. Fork this repository.
2. Set up an IAM user in AWS with the necessary permissions to support the docker-build.yml workflow script included. Refer to [this ticket](https://jiraent.cms.gov/browse/CLDSPT-3127) for a previous implementation.
    * Once you have your user, be sure to populate your repository secrets with its access keys
    * Refer to the [docs](docs) for past ADRs regarding the IAM user and GitHub actions workflow considerations. In particular, you will need to manually change your ECR repository name.
3. Provision the Terraform module in this repository.
4. You should now be able to push images to your ECR repository via a push to your main branch or a new release.

**(WIP)**
To be populated with more details on how to get this operationalized via ECS/Fargate.

## Local Usage for Testing
1. Clone this repository to your machine.
2. Populate the `entrypoint.sh` script with your GitHub personal access token, the repository owner, and repository name.
3. Build and run the image. `./entrypoint.sh` should register the runner with your repository and start listening for jobs.
4. In one of the workflows in the target repository, change the `runs-on` value to `self-hosted`. This will make the workflow use the registered self-hosted runner to complete its task, after which it will shut down.