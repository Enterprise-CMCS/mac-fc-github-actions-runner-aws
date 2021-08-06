#!/bin/bash
set -ex

# install dependencies
apt-get update
apt-get -qq -y install --no-install-recommends \
    ca-certificates curl tar git \
    libyaml-dev build-essential jq uuid-runtime

# Install our user and create directory to install actions-runner and the hostedtoolcache
addgroup --gid 1000 "${RUNGROUP}" && adduser --uid 1000 --ingroup "${RUNGROUP}" --shell /bin/bash "${RUNUSER}"
mkdir -p "/home/${RUNUSER}/actions-runner"
mkdir -p "/opt/hostedtoolcache"

# These steps are straight from the github runner installation guide when attempting to add a runner to a repository
cd "/home/${RUNUSER}/actions-runner"

# Download the latest runner package
curl -o "actions-runner-linux-x64-${ACTIONS_VERSION}.tar.gz" -L "https://github.com/actions/runner/releases/download/v${ACTIONS_VERSION}/actions-runner-linux-x64-${ACTIONS_VERSION}.tar.gz"

# Extract installer
tar xzf "./actions-runner-linux-x64-${ACTIONS_VERSION}.tar.gz"

# Install .Net Core 3.x Linux Dependencies
./bin/installdependencies.sh

# give privileges to our user
chown -R "${RUNUSER}":"${RUNGROUP}" "/opt/hostedtoolcache"
chown -R "${RUNUSER}":"${RUNGROUP}" "/home/${RUNUSER}"