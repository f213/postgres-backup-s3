#! /bin/sh

set -e

if [ "$S3_S3V4" = "yes" ]; then
    aws configure set default.s3.signature_version s3v4
fi

if [ "$SCHEDULE" = "**None**" ]; then
  echo You need to set up SCHEDULE env var
  exit 127
else
  echo "$SCHEDULE /bin/sh /backup.sh" > /etc/crontab.backup
  exec supercronic -debug -prometheus-listen-address 0.0.0.0 /etc/crontab.backup
fi
