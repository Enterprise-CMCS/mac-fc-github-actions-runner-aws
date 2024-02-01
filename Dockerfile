FROM gcr.io/kaniko-project/executor:debug as kaniko

FROM 037370603820.dkr.ecr.us-east-1.amazonaws.com/github-actions-runner:89f3025

COPY --from=kaniko /kaniko /kaniko

ENV PATH=/kaniko:$PATH
ENV DOCKER_CONFIG='/kaniko/.docker'
ENV SSL_CERT_DIR=/kaniko/ssl/certs