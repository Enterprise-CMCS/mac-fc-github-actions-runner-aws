# CloudFormation for GitHub OIDC

Please see the [top-level README](../README.md) for general information about GitHub OIDC.

## Usage

### Parameters

- `SubjectClaimFilters` is a comma-separated list of subject claims that configure the GitHub branch or environment that is permitted to perform AWS actions via the OIDC provider. See the [top-level README](../README.md) for details.

The permissions policy is defined by two optional parameters:

- `GitHubActionsAllowedAWSActions` is a comma-separated list of strings that are comprised of an AWS service and an allowed action. See the [IAM documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements_action.html) for examples. The service/action pairs listed will be granted access to all resources (`"Resource": "*"`).
- `ManagedPolicyARNs` is a comma-separated list of IAM policy ARNs to attach to the OIDC role. These can be AWS-managed or custom-managed policy ARNs.

### Steps

1. For each AWS environment, create a parameters JSON file with the values needed for that environment. An [example file](./parameters-example.json) is provided.

2. Deploy the OIDC resources in each AWS environment using [the provided CloudFormation template](.github/oidc/github-actions-oidc-template.yml) and the AWS CLI:

   - Verify the AWS account for the deploy

     ```console
     aws sts get-caller-identity
     ```

   - View the proposed changes using the `--no-execute-changeset` flag

     ```console
     aws cloudformation deploy \
       --template-file github-oidc.yml \
       --stack-name github-oidc \
       --parameter-overrides file://{path to parameters file} \
       --capabilities CAPABILITY_IAM \
       --no-execute-changeset
     ```

   - Verify the changes, then deploy

     ```console
     aws cloudformation deploy \
       --template-file github-oidc.yml \
       --stack-name github-oidc \
       --parameter-overrides file://{path to parameters file} \
       --capabilities CAPABILITY_IAM
     ```

   - Get the service role ARN from the stack output

   ```console
   aws cloudformation describe-stacks --stack-name github-oidc --query "Stacks[0].Outputs[?OutputKey=='ServiceRoleARN'].OutputValue" --output text
   ```

3. For each environment, create a repository secret in `GitHub Secrets -> Actions` where the key is `${environment}_OIDC_IAM_ROLE_ARN` and the value is the ARN of the role for that environment. Refer to this secret when configuring credentials for a given environment in a workflow.
