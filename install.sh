#! /bin/sh

# exit if a command fails
set -e


apk update

# install pg_dump
apk --no-cache add postgresql-client

# install dump-init
apk --no-cache add dumb-init

# install s3 tools
apk --no-cache add aws-cli bash findutils groff less python3 tini inotify-tools

# install go-cron
apk add curl
curl -L https://github.com/odise/go-cron/releases/download/v0.0.7/go-cron-linux.gz | zcat > /usr/local/bin/go-cron
chmod u+x /usr/local/bin/go-cron


# cleanup
rm -rf /var/cache/apk/*
