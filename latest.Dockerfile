FROM alpine:3.20.2 AS install

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

# install libicu for Ubuntu 24.04
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

WORKDIR /home/runner
USER runner

# keep this layer last so changes to the entrypoint script don't trigger rebuilds
COPY --chown=runner:runner entrypoint.sh .
ENTRYPOINT ["./entrypoint.sh"]
