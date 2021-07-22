# Create Iam user to push container images into ECR repo

In order for github actions to push new container images into the ECR repo we need an Iam user. This Iam user will have write permissions to the ECR repo created as part of terraform module.

Date: 2021-03-01

Author: @rdhariwal

## Manual Work Performed

* apply terraform module and get the arn for the ECR repo created by the module
* file a ticket with [CMS Cloud Support team](https://jiraent.cms.gov/plugins/servlet/desk/portal/22) to create an Iam user with the following policy.
* update the resource arn with your ECR repo's arn
* Add `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` to gihub secrets from IAM user created in steps above

## AWS Accounts

* [ ] aws-cms-oit-iusg-spe-cmcs-macbis-dev

## Reason for Manual Execution

Because CMS limits creation of Iam users we need a workaround to create an Iam user that will have permission to push to ECR repo.