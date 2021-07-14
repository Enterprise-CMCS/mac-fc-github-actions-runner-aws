FROM ubuntu:18.04

COPY build.sh /tmp
RUN /tmp/build.sh

COPY entrypoint.sh .
ENTRYPOINT ["./entrypoint.sh"]