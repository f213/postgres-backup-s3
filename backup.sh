#! /bin/sh

set -e
set -o pipefail

# shellcheck disable=SC2086  # AWS_ARGS, POSTGRES_HOST_OPTS intentionally word-splitted

if [ "${S3_ACCESS_KEY_ID}" = "**None**" ]; then
  echo "You need to set the S3_ACCESS_KEY_ID environment variable."
  exit 1
fi

if [ "${S3_SECRET_ACCESS_KEY}" = "**None**" ]; then
  echo "You need to set the S3_SECRET_ACCESS_KEY environment variable."
  exit 1
fi

if [ "${S3_BUCKET}" = "**None**" ]; then
  echo "You need to set the S3_BUCKET environment variable."
  exit 1
fi

if [ "${POSTGRES_DATABASE}" = "**None**" ]; then
  echo "You need to set the POSTGRES_DATABASE environment variable."
  exit 1
fi

if [ "${POSTGRES_HOST}" = "**None**" ]; then
  if [ -n "${POSTGRES_PORT_5432_TCP_ADDR}" ]; then
    POSTGRES_HOST="${POSTGRES_PORT_5432_TCP_ADDR}"
    POSTGRES_PORT="${POSTGRES_PORT_5432_TCP_PORT}"
  else
    echo "You need to set the POSTGRES_HOST environment variable."
    exit 1
  fi
fi

if [ "${POSTGRES_USER}" = "**None**" ]; then
  echo "You need to set the POSTGRES_USER environment variable."
  exit 1
fi

if [ "${POSTGRES_PASSWORD}" = "**None**" ]; then
  echo "You need to set the POSTGRES_PASSWORD environment variable or link to a container named POSTGRES."
  exit 1
fi

if [ "${S3_ENDPOINT}" = "**None**" ]; then
  AWS_ARGS=""
else
  AWS_ARGS="--endpoint-url ${S3_ENDPOINT}"
fi

# экспорт переменных для aws cli
export AWS_ACCESS_KEY_ID="${S3_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${S3_SECRET_ACCESS_KEY}"
export AWS_DEFAULT_REGION="${S3_REGION}"

# экспорт для pg_dump
export PGPASSWORD="${POSTGRES_PASSWORD}"
POSTGRES_HOST_OPTS="-h ${POSTGRES_HOST} -p ${POSTGRES_PORT} -U ${POSTGRES_USER} ${POSTGRES_EXTRA_OPTS}"

# даты в UTC
NOW_UTC=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# вычисляем дату "вчера" и "завтра" c помощью TZ (хак для busybox date)
YESTERDAY_DATE=$(TZ=GMT+24 date +%Y-%m-%d)
TOMORROW_DATE=$(TZ=GMT-24 date +%Y-%m-%d)
NEXT_DAY_OF_MONTH=$(echo "$TOMORROW_DATE" | cut -d- -f3)

echo "Creating dump of ${POSTGRES_DATABASE} database from ${POSTGRES_HOST}..."
pg_dump -Fc ${POSTGRES_HOST_OPTS} "${POSTGRES_DATABASE}" > db.dump

echo "Uploading dump to ${S3_BUCKET}..."
UPLOADED_FILE_KEY="${S3_PREFIX}/${POSTGRES_DATABASE}_${NOW_UTC}.dump"

aws ${AWS_ARGS} s3 cp db.dump "s3://${S3_BUCKET}/${UPLOADED_FILE_KEY}" || {
  echo "Failed to upload dump to S3"
  exit 2
}

echo "DB backup uploaded successfully: s3://${S3_BUCKET}/${UPLOADED_FILE_KEY}"

rm db.dump

# Логика удаления бэкапа за вчера, если вчера не последний день месяца
if [ "$NEXT_DAY_OF_MONTH" = "01" ]; then
  echo "Yesterday (${YESTERDAY_DATE}) was the last day of the month. Keeping backup."
else
  DELETE_FILE_PREFIX="${S3_PREFIX}/${POSTGRES_DATABASE}_${YESTERDAY_DATE}"
  echo "Deleting backups with prefix '${DELETE_FILE_PREFIX}'..."

  FILES_TO_DELETE=$(aws ${AWS_ARGS} s3api list-objects-v2 --bucket "${S3_BUCKET}" --prefix "${DELETE_FILE_PREFIX}" --query "Contents[].Key" --output text || true)

  if [ -z "$FILES_TO_DELETE" ]; then
    echo "No backups found to delete for yesterday (${YESTERDAY_DATE})."
  else
    echo "$FILES_TO_DELETE" | while read -r file_key; do
      if [ -n "$file_key" ]; then
        echo "Deleting s3://${S3_BUCKET}/$file_key"
        aws ${AWS_ARGS} s3 rm "s3://${S3_BUCKET}/$file_key"
      fi
    done
  fi
fi

# Уведомление об успешном бэкапе
if [ ! "${SUCCESS_WEBHOOK}" = "**None**" ]; then
  echo "Notifying ${SUCCESS_WEBHOOK}"
  curl -m 10 --retry 5 "${SUCCESS_WEBHOOK}"
fi