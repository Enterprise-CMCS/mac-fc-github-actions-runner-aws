#!/bin/bash
set -ex

mkdir work-dir

# Grab a runner registration token
# https://docs.github.com/en/rest/actions/self-hosted-runners#create-a-registration-token-for-a-repository
status_code=$(curl \
    -s \
    -w "%{http_code}" \
    -o /tmp/token_response.json \
    -X POST \
    -H "Authorization: token ${PERSONAL_ACCESS_TOKEN}" \
    "https://api.github.com/orgs/Enterprise-CMCS/runners/registration-token" \
    )

if [[ $status_code == "201" ]]
then
    REGISTRATION_TOKEN=$(jq -r ".token" /tmp/token_response.json)
else
    echo "Got status code $status_code trying to create a GitHub repo registration token."
    echo "Response: $(cat /tmp/token_response.json)"
    exit 1
fi

# Use the RUNNER_UUID env var if it exists
UNIQUE_ID=${RUNNER_UUID:-$(uuidgen)}

# Register the runner:
# - disable updates since we manage them manually via the container image
#   - https://docs.github.com/en/actions/hosting-your-own-runners/autoscaling-with-self-hosted-runners#controlling-runner-software-updates-on-self-hosted-runners
# - register as an ephemeral runner
#   - https://docs.github.com/en/actions/hosting-your-own-runners/autoscaling-with-self-hosted-runners#using-ephemeral-runners-for-autoscaling
# - labels argument to config.sh is a comma-separated list
#    - https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/using-labels-with-self-hosted-runners#programmatically-assign-labels

LABELS=$(echo "$UNIQUE_ID" "$RUNNER_LABELS" | tr ' ' ',' )

./config.sh \
      --unattended \
      --url "https://github.com/Enterprise-CMCS"  \
      --token "${REGISTRATION_TOKEN}" \
      --name "${UNIQUE_ID}" \
      --labels "${LABELS}" \
      --work work-dir \
      --replace \
      --disableupdate \
      --ephemeral

./run.sh
