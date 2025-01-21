FROM alpine:3.21.0 AS install

RUN apk add --update --no-cache \
    curl \
    tar \
    ca-certificates

ARG ACTIONS_VERSION
RUN test -n "$ACTIONS_VERSION" || (echo "ACTIONS_VERSION not set" && exit 1)

RUN \
    # install runner
    curl -sL --create-dirs -o "actions-runner-linux-x64-${ACTIONS_VERSION}.tar.gz" "https://github.com/actions/runner/releases/download/v${ACTIONS_VERSION}/actions-runner-linux-x64-${ACTIONS_VERSION}.tar.gz" \
    && mkdir runner \
    && tar xzf "actions-runner-linux-x64-${ACTIONS_VERSION}.tar.gz" --directory ./runner

FROM ubuntu:25.04

RUN groupadd "runner" && useradd -g "runner" --shell /bin/bash "runner" \
    && mkdir -p "/home/runner" \
    && chown -R "runner":"runner" "/home/runner"

COPY --from=install /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=install ./runner /home/runner

# install libicu for Ubuntu 25.04
# https://github.com/actions/runner/issues/3150
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libicu-dev \
    && rm -rf /var/lib/apt/lists

# install runner dependencies
RUN /home/runner/bin/installdependencies.sh

# install entrypoint.sh dependencies (separately since these change more often)
RUN apt-get update \
    && apt-get -qq -y install --no-install-recommends \
    curl \
    jq \
    uuid-runtime \
    unzip \
    && rm -rf /var/lib/apt/lists

# install awscli because the standard runner has it
# per https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install

# Remove setuid and setgid permissions after all package installations to address
# https://github.com/goodwithtech/dockle/blob/master/CHECKPOINT.md#cis-di-0008
RUN find / -path /proc -prune -o -perm /6000 -type f -exec chmod a-s {} + || true

WORKDIR /home/runner
USER runner

# keep this layer last so changes to the entrypoint script don't trigger rebuilds
COPY --chown=runner:runner entrypoint.sh .
ENTRYPOINT ["./entrypoint.sh"]
