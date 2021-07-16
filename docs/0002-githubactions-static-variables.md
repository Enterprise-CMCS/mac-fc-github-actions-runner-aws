# Update environment values for github actions

In order for github actions to push new container images into the ECR repo we need the following environment variables updated.

1. `aws-region` found in `.github/workflows/docker-build.yml` with your region for example: `us-east-1`
1. `ECR_REPOSITORY` repo name found in the output of the terraform module in this repo

Date: 2021-03-08

Author: @rdhariwal

## Manual Work Performed

* update the values for `aws-region` and `ECR_REPOSITORY` in `.github/workflows/docker-build.yml`

## Reason for Manual Execution

Because the values for the aws region and the name of the ECR repo depend on user supplied values.