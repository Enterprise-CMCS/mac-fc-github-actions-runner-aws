FROM ubuntu:18.04

ARG REPOSITORY=https://github.com/chtakahashi/testing-self-hosted-runners
ARG REPOSITORY_TOKEN=

ARG RUNUSER=default
ARG RUNGROUP=default

COPY build.sh /tmp

RUN chmod u+x /tmp/build.sh
RUN /tmp/build.sh

ENTRYPOINT ["/actions-runner/run.sh"]