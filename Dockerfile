FROM alpine:3.22.1
LABEL maintainer="Fedor Borshev <fedor@borshev.com>"

ARG POSTGRES_VERSION=17

RUN apk update \
    && apk --no-cache add dumb-init postgresql${POSTGRES_VERSION}-client curl aws-cli supercronic


ENV POSTGRES_DATABASE **None**
ENV POSTGRES_HOST **None**
ENV POSTGRES_PORT 5432
ENV POSTGRES_USER **None**
ENV POSTGRES_PASSWORD **None**
ENV POSTGRES_EXTRA_OPTS ''
ENV S3_ACCESS_KEY_ID **None**
ENV S3_SECRET_ACCESS_KEY **None**
ENV S3_BUCKET **None**
ENV S3_REGION us-west-1
ENV S3_PATH 'backup'
ENV S3_ENDPOINT **None**
ENV S3_S3V4 no
ENV SCHEDULE **None**
ENV SUCCESS_WEBHOOK **None**

ADD entrypoint.sh .
ADD backup.sh .

HEALTHCHECK CMD curl --fail http://localhost:9746/health || exit 1

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["sh", "entrypoint.sh"]
