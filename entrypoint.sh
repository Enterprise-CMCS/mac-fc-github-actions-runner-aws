#!/bin/bash
set -ex

GITHUB_TOKEN=#removed
OWNER=chtakahashi
REPO=testing-self-hosted-runners

REGISTRATION_TOKEN=$(curl -s -X POST \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    "https://api.github.com/repos/${OWNER}/${REPO}/actions/runners/registration-token" | jq -r .token)

cd "/home/default/actions-runner"
mkdir work-dir

./config.sh \
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
  ./config.sh remove --token "${REGISTRATION_TOKEN}"

  # Remove our runner work dir to clean up after ourselves
  rm -rf work-dir
}

trap cleanup EXIT
./run.sh --once