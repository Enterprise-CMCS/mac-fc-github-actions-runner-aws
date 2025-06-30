FROM alpine:3.21.3 as install

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

FROM mcr.microsoft.com/playwright:v1.38.0-focal

RUN groupadd "runner" && useradd -g "runner" --shell /bin/bash "runner" \
    && mkdir -p "/home/runner" \
    && chown -R "runner":"runner" "/home/runner"

COPY --from=install /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=install ./runner /home/runner

# install runner dependencies
RUN /home/runner/bin/installdependencies.sh

# install entrypoint.sh dependencies (separately since these change more often)
RUN apt-get update \
    && apt-get -qq -y install --no-install-recommends \
    curl \
    jq \
    uuid-runtime \
    unzip \
    && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists

# install awscli because the standard runner has it
# per https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install

WORKDIR /home/runner
USER runner

# keep this layer last so changes to the entrypoint script don't trigger rebuilds
COPY --chown=runner:runner entrypoint.sh .
ENTRYPOINT ["./entrypoint.sh"]
