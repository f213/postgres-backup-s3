FROM alpine:3.16.3
LABEL maintainer="Fedor Borshev <fedor@borshev.com>"

RUN apk update \
    && apk --no-cache add dumb-init postgresql-client curl aws-cli

RUN curl -L https://github.com/odise/go-cron/releases/download/v0.0.7/go-cron-linux.gz | zcat > /usr/local/bin/go-cron && chmod +x /usr/local/bin/go-cron

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

ADD entrypoint.sh .
ADD backup.sh .

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["sh", "entrypoint.sh"]
