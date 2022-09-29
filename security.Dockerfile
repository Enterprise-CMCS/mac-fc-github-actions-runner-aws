FROM alpine:3.16.2 as install

RUN apk add --update --no-cache \
    curl \
    tar \
    zip \
    ca-certificates

ARG ACTIONS_VERSION="2.297.0"

RUN \
    # install sonar scanner
    curl -sL https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.7.0.2747-linux.zip -o sonar-scanner.zip \
    && unzip sonar-scanner.zip \
    # install runner
    && curl -sL --create-dirs -o "actions-runner-linux-x64-${ACTIONS_VERSION}.tar.gz" "https://github.com/actions/runner/releases/download/v${ACTIONS_VERSION}/actions-runner-linux-x64-${ACTIONS_VERSION}.tar.gz" \
    && mkdir runner \
    && tar xzf "actions-runner-linux-x64-${ACTIONS_VERSION}.tar.gz" --directory ./runner


FROM ubuntu:22.04

RUN addgroup --gid 1000 "runner" && adduser --uid 1000 --ingroup "runner" --shell /bin/bash "runner" \
    && mkdir -p "/home/runner" \
    && chown -R "runner":"runner" "/home/runner" \
    && mkdir -p "/opt/hostedtoolcache" \
    && chown -R "runner":"runner" "/opt/hostedtoolcache"

COPY --from=install /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=install sonar-scanner-4.7.0.2747-linux /opt/hostedtoolcache/sonar-scanner
COPY --from=install ./runner /home/runner

# install runner dependencies
RUN /home/runner/bin/installdependencies.sh

# install entrypoint.sh dependencies (separately since these change more often)
RUN apt-get update \
    && apt-get -qq -y install --no-install-recommends \
    curl \
    jq \
    uuid-runtime \
    && rm -rvf /var/lib/apt/lists/*

ENV PATH="/opt/hostedtoolcache/sonar-scanner/bin:${PATH}"
WORKDIR /home/runner
USER runner

# keep this layer last so changes to the entrypoint script don't trigger rebuilds
COPY --chown=runner:runner entrypoint.sh .
ENTRYPOINT ["./entrypoint.sh"] TODO revert
