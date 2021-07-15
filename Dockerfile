FROM ubuntu:18.04

ARG RUNUSER=default
ARG RUNGROUP=default

COPY build.sh /tmp

RUN /tmp/build.sh

COPY --chown=${RUNUSER}:${RUNGROUP} entrypoint.sh /home/${RUNUSER}

RUN rm -rf /tmp/*

WORKDIR /home/${RUNUSER}
USER ${RUNUSER}

ENTRYPOINT ["./entrypoint.sh"]