# Using a Self-Hosted GitHub Runner for your GitHub Actions Jobs

NEVER USE A SELF-HOSTED GITHUB RUNNER ON A PUBLIC REPOSITORY - Any individual may open a pull request against your repository and run malicious code in your runner environment.

## About

As a part of your GitHub actions workflows, you may need access to internal CMS tooling that is inaccessible from GitHub's hosted runners. Using a self-hosted runner with access to the CMS network would solve this problem.

## Using the Runner

This procedure assumes that you have already taken the steps documented in the main README. You have:

- Requested an IAM user and verified its access requirements
- Instantiated the requisite infrastructure in AWS ECR and ECS

### Provisioning the Runners

We will use GitHub actions to provision the requisite number of runners we need we need.

In the root of your repository, create a directory to house your workflow and a yml file for the workflow:

```sh
mkdir -p .github/workflow
touch .github/workflow/your-workflow.yml
```

Your workflow must contain the start-runner and remove-runners jobs listed below.

```yaml
name: your-workflow-name

on:
  push:
    branches: [main]

name: internal runners test

jobs:
  start-runner:
    name: Provision self-hosted runners
    runs-on: ubuntu-latest
    steps:
      - name: TrussWorks Provisioning Action
        uses: trussworks/ecs-scaleup@v3.0.0
        id: truss
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
          ecr-repository: github-runner
          image-tag: latest
          repository-hash:
          desired-count: 3

  test_self_hosted:
    name: Testing self-hosted tag
    needs: start-runner
    runs-on: self-hosted
    steps:
      - name: step 1
        run: echo "Hello World!"

  test_internal_tools:
    name: Testing internal tool connectivity
    needs: start-runner
    runs-on: self-hosted
    steps:
      - name: curl selenium
        run: curl --connect-timeout 5 https://selenium.cloud.cms.gov
      - name: curl artifactory
        run: curl --connect-timeout 5 https://artifactory.cloud.cms.gov/ui/packages

  test_hosted_tools:
    name: Testing runner directories
    needs: start-runner
    runs-on: self-hosted
    steps:
      - name: ls /opt/hostedtoolcache
        run: ls -al /opt/hostedtoolcache
      - name: ls /home/runner
        run: ls -al /home/runner

  remove-runners:
    name: Deprovision self-hosted runners
    needs: [start-runner, test_self_hosted, test_internal_tools, test_hosted_tools]
    runs-on: ubuntu-latest
    steps:
      - name: TrussWorks Deprovisioning Action
        uses: trussworks/ecs-scaledown@v2.0.0
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: "us-east-1"
          repository-hash:
```

The items to configure are:

- **Your AWS Access Key and Secret Access Keys**. These should be populated in your repository secrets.

- All variables in the **top-level env** configuration of the workflow:

  - AWS_REGION - your AWS region, e.g. us-east-1
  - ECR_REPOSITORY - the name of the ECR repository in which you are housing your self-hosted runner images
  - IMAGE_TAG - the unique tag of a specific image to pull from your ECR repository. For example, "latest", which is updated each time a new image is pushed to ECR.
  - DESIRED_COUNT: The number of runners you will need. For example, if you have 3 jobs following the start-runner task, you should populate this with the value 3.

- **Your jobs**. Any existing workflows that you have that you wish to run on a self-hosted runner can be run by simply changing the `runs-on` argument from a GitHub hosted tag (e.g. `ubuntu-latest`) to `self-hosted`.
- **The `needs` variable** under the `remove-runners` job. In order to ensure that the runners are removed following the completion of the tasks and not any sooner, you must populate the list of steps that the `remove-runners` job depends on with the full list of your jobs.

  - For example, if you have a workflow that looks like:

    ```yaml
    jobs:
      start-runner:
        ...
      job1:
        ...
      job2:
        ...
      job3:
        ...
      remove-runners:
        ...
    ```

    then your `needs` variable under `remove-runner` should be populated with `[start-runner, job1, job2, job3]`.
