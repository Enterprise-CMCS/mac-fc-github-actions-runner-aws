# github-oidc

This module creates the resources necessary to use GitHub's OIDC provider to retrieve short-term credentials from AWS for performing AWS API calls in an Actions workflow. The advantage of this approach is that there is no need to create an IAM user and store long-term AWS credentials in GitHub secrets.

[Read more about configuring OpenID Connect in AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)

## IAM Permissions

The resources created by this module include a policy that establishes the trust relationship between GitHub and AWS. However, an additional policy is needed to grant permissions to perform AWS actions in the workflow. For example, if the workflow is scaling self-hosted runners in ECS or importing findings to Security Hub, a policy granting those permissions would need to be attached to the role that the AWS OIDC provider federates to upon getting a token from the GitHub OIDC provider. This module assumes that such a policy will be named `github_actions_permission_policy.json` and located in the same folder as the root module (the path and filename are configurable via the `github_actions_permissions_policy_json_path` variable)

## Subject Claims

Subject claims allow you to configure the GitHub branch or environment that is permitted to perform AWS actions via the OIDC provider. [Read more about subject claims](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect#example-subject-claims)

## Examples

### Consuming the module

This module is located in a sub-directory, since some users may wish to consume this module even if they don't need to set up self-hosted runners. Note that to refer to a sub-directory as a module source, you need to [include a double slash before the sub-directory](https://developer.hashicorp.com/terraform/language/modules/sources#modules-in-package-sub-directories).

`github-oidc/main.tf`

```hcl
  module "github-actions-runner-aws" {
    source = "github.com/CMSgov/github-actions-runner-aws//github-oidc" # double-slash denotes a sub-directory

    subject_claim_filters                         = ["repo:{your GitHub org}/{your GitHub repo}:*"]
    # audience_list                               = [] # optional, defaults to ["sts.amazonaws.com"]
    # thumbprint_list                             = [] # optional, defaults to ["6938fd4d98bab03faadb97b34396831e3780aea1"]
    # github_actions_permissions_policy_json_path = "" # optional, defaults to "github_actions_permission_policy.json"
    # add_read_only_access                        = bool # optional, defaults to false
    # existing_iam_oidc_provider_arn              = "" # optional, defaults to empty string. if using an existing provider, provide the ARN here and the module will skip creating it one since there can only be one provider for token.actions.githubusercontent.com.  Note that the audience list of the existing provider must include any audiences configured with this module (e.g. the default vaule of 'sts.amazonaws.com')
  }
```

`github-oidc/github_actions_permission_policy.json`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": ["securityhub:BatchImportFindings"],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Sid": "UpdateService",
      "Effect": "Allow",
      "Action": ["ecs:UpdateService"],
      "Resource": [
        "arn:aws:ecs:{your region}:{your account number}:service/{your self-hosted runner cluster name}/{your github runner service name}"
      ]
    }
  ]
}
```

### Using the OIDC provider in a workflow

Note that the `id-token` permission is [required to authorize the request for the GitHub OIDC token](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect#adding-permissions-settings). You can set the permission globally, or per job. If you forget this step, you will see the error `Error: Credentials could not be loaded, please check your action inputs: Could not load credentials from any providers`.

```yml
jobs:
  example:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
    steps:

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-region: us-east-1
          role-to-assume: ${ARN of the role created by this module}

     ...
```

We recommend that you store the ARN of the role created by this module as a GitHub secret called `OIDC_IAM_ROLE_ARN`, to make it easy to refer to the ARN in workflow runs.
