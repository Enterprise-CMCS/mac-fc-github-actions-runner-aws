#!/bin/bash
set -ex

mkdir work-dir
cd actions-runner

# Grab a runner registration token
REGISTRATION_TOKEN=$(curl -s -X POST \
    -H "Authorization: token ${PERSONAL_ACCESS_TOKEN}" \
    "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/actions/runners/registration-token" | jq -r .token)

UNIQUE_ID=$(uuidgen)

# Register the runner
./config.sh \
      --unattended \
      --url "https://github.com/${REPO_OWNER}/${REPO_NAME}" \
      --token "${REGISTRATION_TOKEN}" \
      --name "${UNIQUE_ID}" \
      --work ../work-dir \
      --replace

cleanup() {
  # give the job a second to finish
  sleep 1
  # Deregister the runner from github
  REGISTRATION_TOKEN=$(curl -s -XPOST \
      -H "Authorization: token ${PERSONAL_ACCESS_TOKEN}" \
      "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/actions/runners/registration-token" | jq -r .token)
  ./config.sh remove --token "${REGISTRATION_TOKEN}"

  # Remove our runner work dir to clean up after ourselves
  rm -rf ../work-dir
}

# Run cleanup upon exit. exit upon one job ran
trap cleanup EXIT
./run.sh --once