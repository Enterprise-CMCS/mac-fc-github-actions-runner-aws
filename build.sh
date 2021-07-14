#!/bin/sh
set -ex

# install dependencies. config.sh uses bash
apt-get update
apt-get -qq -y install --no-install-recommends ca-certificates curl tar

mkdir actions-runner && cd actions-runner

curl -o actions-runner-linux-x64-2.278.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.278.0/actions-runner-linux-x64-2.278.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.278.0.tar.gz
./bin/installdependencies.sh

RUNNER_ALLOW_RUNASROOT="1" ./config.sh --url ${REPOSITORY} --token ${REPOSITORY_TOKEN}
