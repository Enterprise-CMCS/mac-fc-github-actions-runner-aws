#!/bin/bash
set -ex

GITHUB_TOKEN=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
OWNER=chtakahashi
REPO=testing-self-hosted-runners

REGISTRATION_TOKEN=$(curl -s -X POST \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    "https://api.github.com/repos/${OWNER}/${REPO}/actions/runners/registration-token" | jq -r .token)

cd actions-runner
mkdir work-dir

RUNNER_ALLOW_RUNASROOT="1" ./config.sh \
      --unattended \
      --url "https://github.com/${OWNER}/${REPO}" \
      --token "${REGISTRATION_TOKEN}" \
      --name "TEST_RUNNER" \
      --work /work-dir \
      --replace

cleanup() {
  # Deregister the runner from github
  REGISTRATION_TOKEN=$(curl -s -XPOST \
      -H "Authorization: token ${GITHUB_TOKEN}" \
      https://api.github.com/repos/${OWNER}/${REPO}/actions/runners/registration-token | jq -r .token)
  RUNNER_ALLOW_RUNASROOT="1" ./config.sh remove --token "${REGISTRATION_TOKEN}"

  # Remove our runner work dir to clean up after ourselves
  rm -rf work-dir
}

trap cleanup EXIT
RUNNER_ALLOW_RUNASROOT="1" ./run.sh --once