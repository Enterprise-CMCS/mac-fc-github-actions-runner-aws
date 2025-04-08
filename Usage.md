# Using a Self-Hosted GitHub Runner for your GitHub Actions Jobs

NEVER USE A SELF-HOSTED GITHUB RUNNER ON A PUBLIC REPOSITORY - Any individual may open a pull request against your repository and run malicious code in your runner environment.

## About

As a part of your GitHub actions workflows, you may need access to internal CMS tooling that is inaccessible from GitHub's hosted runners. Using a self-hosted runner with access to the CMS network solves this problem.

## Prerequisites

This procedure assumes that you have already taken the steps documented in the main README. You have:

- Instantiated the requisite infrastructure in AWS ECR and ECS
- Instantiated the resources for the GitHub OIDC provider and noted the OIDC role ARN

## Usage

In the root of your repository, create a directory to house your workflow and a `.yml` file for the workflow:

```sh
mkdir -p .github/workflow
touch .github/workflow/your-workflow.yml
```

Your workflow must contain the `start-runners` and `stop-runners` jobs listed below.

```yaml
name: your-workflow-name

on:
  push:
    branches: [main]

name: internal runners test

permissions:
  id-token: write # this permission is required to authorize the request for the GitHub OIDC token used by the configure-aws-credentials action

jobs:
  start-runners:
    name: Provision self-hosted runners
    runs-on: ubuntu-latest
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-region: us-east-1
          role-to-assume: arn:aws:iam::123456789012:role/delegatedadmin/developer/github-actions-oidc

      - name: Scale up ECS service
        uses: Enterprise-CMCS/ecs-scale-service@main
        with:
          cluster: ${{ your self-hosted runner cluster }}
          service: ${{ your self-hosted runner service }}
          desired-count: 2

  test-self-hosted:
    name: Testing self-hosted tag
    needs: start-runners
    runs-on: self-hosted
    steps:
      - name: step 1
        run: echo "Hello World!"

  test-internal-tools:
    name: Testing internal tool connectivity
    needs: start-runners
    runs-on: self-hosted
    steps:
      - name: curl selenium
        run: curl --connect-timeout 5 https://selenium.cloud.cms.gov
      - name: curl artifactory
        run: curl --connect-timeout 5 https://artifactory.cloud.cms.gov/ui/packages

  stop-runners:
    name: Deprovision self-hosted runners
    runs-on: ubuntu-latest
    if: always()
    needs: [start-runners, test-self-hosted, test-internal-tools]
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-region: us-east-1
          role-to-assume: arn:aws:iam::123456789012:role/delegatedadmin/developer/github-actions-oidc

      - name: Scale down ECS service
        uses: Enterprise-CMCS/ecs-scale-service@main
        with:
          cluster: ${{ your self-hosted runner cluster }}
          service: ${{ your self-hosted runner service }}
          desired-count: 0
```

Any existing workflows that you have that you wish to run on a self-hosted runner can be run by simply changing the `runs-on` argument from a GitHub hosted tag (e.g. `ubuntu-latest`) to `self-hosted`.

In order to ensure that the runners are removed following the completion of the tasks and not any sooner, you must populate the list of steps that the `remove-runners` job depends on with the full list of your jobs. For example, if you have a workflow that looks like:

```yaml
jobs:
  start-runners: ...
  job1: ...
  job2: ...
  job3: ...
  stop-runners: ...
```

then your `needs` variable under `stop-runners` should be populated with `[start-runners, job1, job2, job3]`. Using `if: always()` on the `stop-runners` job ensures that the runners will be deprovisioned even if some of the workflows on the runners fail.

## Tools

The self-hosted runner image is intentionally lightweight and contains the following tools:

- the Actions runner
- curl
- jq
- uuid-runtime
- unzip

You should be sure to install any other prerequisites onto the self-hosted runner before the steps that require them. For example, you could use the [setup-node](https://github.com/actions/setup-node) action before any steps that require Node.

```yaml
- name: Set up Node
  uses: actions/setup-node@v4
  with:
    node-version: 20
```
