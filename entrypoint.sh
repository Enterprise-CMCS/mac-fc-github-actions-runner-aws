#!/bin/bash
set -ex

mkdir work-dir
cd actions-runner

# Grab a runner registration token
REGISTRATION_TOKEN=$(curl -s -X POST \
    -H "Authorization: token ${PERSONAL_ACCESS_TOKEN}" \
    "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/actions/runners/registration-token" | jq -r .token)

UNIQUE_ID=$(uuidgen)

# Register the runner:
# - disable updates since we manage them manually via the container image
#   - https://docs.github.com/en/actions/hosting-your-own-runners/autoscaling-with-self-hosted-runners#controlling-runner-software-updates-on-self-hosted-runners
# - register as an ephemeral runner
#   - https://docs.github.com/en/actions/hosting-your-own-runners/autoscaling-with-self-hosted-runners#using-ephemeral-runners-for-autoscaling
./config.sh \
      --unattended \
      --url "https://github.com/${REPO_OWNER}/${REPO_NAME}" \
      --token "${REGISTRATION_TOKEN}" \
      --name "${UNIQUE_ID}" \
      --work ../work-dir \
      --replace \
      --disableupdate \
      --ephemeral

./run.sh
