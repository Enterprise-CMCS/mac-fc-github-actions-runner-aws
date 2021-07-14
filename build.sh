#!/bin/bash
set -ex

# install dependencies
apt-get update
apt-get -qq -y install --no-install-recommends \
    ca-certificates curl tar git \
    libyaml-dev build-essential jq

mkdir actions-runner
cd actions-runner

# Download the latest runner package
curl -o actions-runner-linux-x64-2.278.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.278.0/actions-runner-linux-x64-2.278.0.tar.gz

# Extract installer 
tar xzf ./actions-runner-linux-x64-2.278.0.tar.gz

# Install .Net Core 3.x Linux Dependencies
./bin/installdependencies.sh