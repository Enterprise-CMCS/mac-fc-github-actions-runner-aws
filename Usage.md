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

name: sample workflow
env:
  AWS_REGION: us-east-1
  ECR_REPOSITORY: github-actions-runner
  IMAGE_TAG: latest
  CONTAINER_NAME: dev-mac-fc-infra
  TASK_DEFINITION: github-runner-dev
  SERVICE: github-actions-runner
  CLUSTER: github-runner
  DESIRED_COUNT: 3
jobs:
  start-runner:
    name: Provision self-hosted runners
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1
      - name: Create ENV variable for image
        id: image-name
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: ${{ env.ECR_REPOSITORY }}
          IMAGE_TAG: ${{ env.IMAGE_TAG }}
        run: echo "::set-output name=image::$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG"
      - name: Grab task definition
        id: get-task-def
        run: |
          aws ecs describe-task-definition \
          --task-definition ${{ env.TASK_DEFINITION }} \
          --query taskDefinition > task-definition.json
      - name: Fill in the new image ID in the Amazon ECS task definition
        id: task-def
        uses: aws-actions/amazon-ecs-render-task-definition@v1
        with:
          task-definition: task-definition.json
          container-name: ${{ env.CONTAINER_NAME }}
          image: ${{ steps.image-name.outputs.image }}
      - name: Increment ECS Service Desired Count
        run: aws ecs update-service --service ${{ env.SERVICE }} --cluster ${{ env.CLUSTER }} --desired-count ${{ env.DESIRED_COUNT }}
      - name: Deploy Amazon ECS task definition
        uses: aws-actions/amazon-ecs-deploy-task-definition@v1
        with:
          task-definition: ${{ steps.task-def.outputs.task-definition }}
          service: ${{ env.SERVICE }}
          cluster: ${{ env.CLUSTER }}
          wait-for-service-stability: true
  ## Your Jobs Here (the number of jobs you have should match the DESIRED_COUNT variable)
  remove-runners:
    name: Deprovision self-hosted runners
    needs: [start-runner, YOUR_JOB_NAMES_HERE]
    runs-on: ubuntu-latest
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      - name: Decrement ECS Service Desired Count
        run: aws ecs update-service --service ${{ env.SERVICE }} --cluster ${{ env.CLUSTER }} --desired-count 0
```

The items to configure are:

- **Your AWS Access Key and Secret Access Keys**. These should be populated in your repository secrets.

- All variables in the **top-level env** configuration of the workflow:

  - AWS_REGION - your AWS region, e.g. us-east-1
  - ECR_REPOSITORY - the name of the ECR repository in which you are housing your self-hosted runner images
  - IMAGE_TAG - the unique tag of a specific image to pull from your ECR repository. For example, "latest", which is updated each time a new image is pushed to ECR.
  - CONTAINER_NAME: The name of the container defined in the containerDefinitions section of the ECS task definition
  - TASK_DEFINITION: The name of the task definition family to pull
  - SERVICE: The name of the ECS service to deploy to
  - CLUSTER: The name of the ECS service's cluster
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
