FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG RUNUSER=runner
ARG RUNGROUP=runner

ARG ACTIONS_VERSION="2.296.2"

COPY build.sh /tmp

RUN /tmp/build.sh

COPY --chown=${RUNUSER}:${RUNGROUP} entrypoint.sh /home/${RUNUSER}

RUN rm -rf /tmp/*

WORKDIR /home/${RUNUSER}
USER ${RUNUSER}

ENTRYPOINT ["./entrypoint.sh"]
