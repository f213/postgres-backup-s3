#! /bin/sh

# shellcheck disable=SC3040  # expecting 'pipefail' derrictive is availabe in the shell
# shellcheck disable=SC2086  # POSTGRES_HOST_OPTS and AWS_ARGS should be splitted by spaces intentionally

set -e
set -o pipefail

if [ "$S3_ACCESS_KEY_ID" = "**None**" ]; then
  echo "You need to set the S3_ACCESS_KEY_ID environment variable."
  exit 1
fi

if [ "$S3_SECRET_ACCESS_KEY" = "**None**" ]; then
  echo "You need to set the S3_SECRET_ACCESS_KEY environment variable."
  exit 1
fi

if [ "$S3_BUCKET" = "**None**" ]; then
  echo "You need to set the S3_BUCKET environment variable."
  exit 1
fi

if [ "$POSTGRES_DATABASE" = "**None**" ]; then
  echo "You need to set the POSTGRES_DATABASE environment variable."
  exit 1
fi

if [ "$POSTGRES_HOST" = "**None**" ]; then
  if [ -n "${POSTGRES_PORT_5432_TCP_ADDR}" ]; then
    POSTGRES_HOST="$POSTGRES_PORT_5432_TCP_ADDR"
    POSTGRES_PORT="$POSTGRES_PORT_5432_TCP_PORT"
  else
    echo "You need to set the POSTGRES_HOST environment variable."
    exit 1
  fi
fi

if [ "$POSTGRES_USER" = "**None**" ]; then
  echo "You need to set the POSTGRES_USER environment variable."
  exit 1
fi

if [ "$POSTGRES_PASSWORD" = "**None**" ]; then
  echo "You need to set the POSTGRES_PASSWORD environment variable or link to a container named POSTGRES."
  exit 1
fi

if [ "$S3_ENDPOINT" = "**None**" ]; then
  AWS_ARGS=""
else
  AWS_ARGS="--endpoint-url $S3_ENDPOINT"
fi

# env vars needed for aws tools
export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$S3_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION="$S3_REGION"

export PGPASSWORD="$POSTGRES_PASSWORD"
POSTGRES_HOST_OPTS="-h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER $POSTGRES_EXTRA_OPTS"

echo "Creating dump of $POSTGRES_DATABASE database from $POSTGRES_HOST..."

pg_dump -Fc $POSTGRES_HOST_OPTS "$POSTGRES_DATABASE" > db.dump

echo "Uploading dump to $S3_BUCKET"

aws $AWS_ARGS s3 cp db.dump "s3://$S3_BUCKET/$S3_PREFIX/${POSTGRES_DATABASE}_$(date +"%Y-%m-%dT%H:%M:%SZ").dump" || exit 2

echo "DB backup uploaded successfully"

rm db.dump

if [ ! "$SUCCESS_WEBHOOK" = "**None**" ]; then
    echo "Notifying $SUCCESS_WEBHOOK"
    curl -m 10 --retry 5 "$SUCCESS_WEBHOOK"
fi
