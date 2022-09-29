FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG RUNUSER=runner
ARG RUNGROUP=runner

ARG ACTIONS_VERSION="2.297.0"

RUN apt-get update \
    && apt-get -qq -y install --no-install-recommends \
    ca-certificates curl tar git \
    libyaml-dev build-essential jq uuid-runtime \
    unzip xvfb gnupg \
    && rm -rvf /var/lib/apt/lists/*

COPY build.sh /tmp

RUN /tmp/build.sh

COPY --chown=${RUNUSER}:${RUNGROUP} entrypoint.sh /home/${RUNUSER}

RUN rm -rf /tmp/*

WORKDIR /home/${RUNUSER}
USER ${RUNUSER}

ENTRYPOINT ["./entrypoint.sh"]
