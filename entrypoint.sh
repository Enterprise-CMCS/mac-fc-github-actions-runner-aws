#!/bin/bash
set -ex

mkdir work-dir
cd actions-runner

# set personal access token, owner, and repo. to be configured via ECS task def
GITHUB_TOKEN=#GitHub Personal Access Token, populate at runtime
OWNER=#GitHub Username
REPO=#GitHub Repository Name

# Grab a runner registration token
REGISTRATION_TOKEN=$(curl -s -X POST \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    "https://api.github.com/repos/${OWNER}/${REPO}/actions/runners/registration-token" | jq -r .token)

# Register the runner
./config.sh \
      --unattended \
      --url "https://github.com/${OWNER}/${REPO}" \
      --token "${REGISTRATION_TOKEN}" \
      --name "TEST_RUNNER" \
      --work ../work-dir \
      --replace

cleanup() {
  # Deregister the runner from github
  REGISTRATION_TOKEN=$(curl -s -XPOST \
      -H "Authorization: token ${GITHUB_TOKEN}" \
      "https://api.github.com/repos/${OWNER}/${REPO}/actions/runners/registration-token" | jq -r .token)
  ./config.sh remove --token "${REGISTRATION_TOKEN}"

  # Remove our runner work dir to clean up after ourselves
  rm -rf ../work-dir
}

# Run cleanup upon exit. exit upon one job ran
trap cleanup EXIT
./run.sh --once