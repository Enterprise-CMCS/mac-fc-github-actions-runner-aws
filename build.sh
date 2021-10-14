#!/bin/bash
set -ex

# install dependencies
apt-get update
apt-get -qq -y install --no-install-recommends \
    ca-certificates curl tar git \
    libyaml-dev build-essential jq uuid-runtime \
    unzip

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

# Install awscliv2
curl -sL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip
unzip awscliv2.zip
./aws/install

# Cleanup archive debris and unnecessary items to reduce image size
rm -rf \
      awscliv2.zip \
      aws \
      /usr/local/aws-cli/v2/*/dist/aws_completer \
      /usr/local/aws-cli/v2/*/dist/awscli/data/ac.index \
      /usr/local/aws-cli/v2/*/dist/awscli/examples \
      "actions-runner-linux-x64-${ACTIONS_VERSION}.tar.gz"

# give privileges to our user
chown -R "${RUNUSER}":"${RUNGROUP}" "/opt/hostedtoolcache"
chown -R "${RUNUSER}":"${RUNGROUP}" "/home/${RUNUSER}"