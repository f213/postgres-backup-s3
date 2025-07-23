#!/bin/sh
set -e
set -o pipefail

# === НАСТРОЙКИ ===
LOG_FILE="/var/log/backup.log"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG_FILE"
}

# --- Проверка переменных окружения ---
if [ "${S3_ACCESS_KEY_ID}" = "**None**" ]; then
  log "You need to set the S3_ACCESS_KEY_ID environment variable."
  exit 1
fi
if [ "${S3_SECRET_ACCESS_KEY}" = "**None**" ]; then
  log "You need to set the S3_SECRET_ACCESS_KEY environment variable."
  exit 1
fi
if [ "${S3_BUCKET}" = "**None**" ]; then
  log "You need to set the S3_BUCKET environment variable."
  exit 1
fi
if [ "${POSTGRES_DATABASE}" = "**None**" ]; then
  log "You need to set the POSTGRES_DATABASE environment variable."
  exit 1
fi
if [ "${POSTGRES_HOST}" = "**None**" ]; then
  if [ -n "${POSTGRES_PORT_5432_TCP_ADDR}" ]; then
    POSTGRES_HOST=$POSTGRES_PORT_5432_TCP_ADDR
    POSTGRES_PORT=$POSTGRES_PORT_5432_TCP_PORT
  else
    log "You need to set the POSTGRES_HOST environment variable."
    exit 1
  fi
fi
if [ "${POSTGRES_USER}" = "**None**" ]; then
  log "You need to set the POSTGRES_USER environment variable."
  exit 1
fi
if [ "${POSTGRES_PASSWORD}" = "**None**" ]; then
  log "You need to set the POSTGRES_PASSWORD environment variable or link to a container named POSTGRES."
  exit 1
fi
if [ "${S3_ENDPOINT}" = "**None**" ]; then
  AWS_ARGS=""
else
  AWS_ARGS="--endpoint-url ${S3_ENDPOINT}"
fi

export AWS_ACCESS_KEY_ID=$S3_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$S3_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=$S3_REGION

export PGPASSWORD=$POSTGRES_PASSWORD
POSTGRES_HOST_OPTS="-h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER $POSTGRES_EXTRA_OPTS"

# === Создание дампа и загрузка в S3 ===
log "Creating dump of ${POSTGRES_DATABASE} database from ${POSTGRES_HOST}..."

if ! pg_dump -Fc $POSTGRES_HOST_OPTS $POSTGRES_DATABASE > db.dump 2>>"$LOG_FILE"; then
  log "pg_dump failed."
  exit 2
fi

FILENAME="${POSTGRES_DATABASE}_$(date +"%Y-%m-%dT%H:%M:%SZ").dump"
S3_PATH="s3://$S3_BUCKET"
if [ -n "$S3_PREFIX" ]; then
  S3_PATH="$S3_PATH/$S3_PREFIX"
fi
S3_PATH="$S3_PATH/$FILENAME"

log "Uploading dump to $S3_PATH"
if ! cat db.dump | aws $AWS_ARGS s3 cp - "$S3_PATH" 2>>"$LOG_FILE"; then
  log "Upload to S3 failed."
  rm -f db.dump
  exit 2
fi

log "DB backup uploaded successfully: $FILENAME"
rm db.dump

if [ -n "$SUCCESS_WEBHOOK" ]; then
  log "Notifying $SUCCESS_WEBHOOK"
  curl -m 10 --retry 5 "$SUCCESS_WEBHOOK" >>"$LOG_FILE" 2>&1
fi

# === Очистка S3: удалять вчерашние бэкапы, кроме последнего дня месяца ===

# Время
YESTERDAY=$(date -d "yesterday" '+%Y-%m-%d')
YESTERDAY_DAY=$(date -d "$YESTERDAY" '+%d')
YESTERDAY_MONTH=$(date -d "$YESTERDAY" '+%m')
YESTERDAY_YEAR=$(date -d "$YESTERDAY" '+%Y')
# Вычисляем последний день месяца для даты "вчера"
LAST_DAY_MONTH=$(date -d "$YESTERDAY +1 month -$(date -d "$YESTERDAY +1 month" '+%d') days" '+%d')

if [ -z "$S3_PREFIX" ]; then
  S3_FULL_PATH="s3://$S3_BUCKET/"
else
  S3_FULL_PATH="s3://$S3_BUCKET/$S3_PREFIX/"
fi

log "=== S3 cleanup: remove backups for previous day except month-end ==="
TMP_REMOVED="/tmp/removed_files.txt"
TMP_KEPT="/tmp/kept_files.txt"
rm -f "$TMP_REMOVED" "$TMP_KEPT"

aws $AWS_ARGS s3 ls "$S3_FULL_PATH" | awk '{print $1, $4}' | while read -r FILE_DATE FILE_NAME; do
  # только файлы
  if [ -z "$FILE_NAME" ]; then continue; fi
  # если файл за вчера
  if [ "$FILE_DATE" = "$YESTERDAY" ]; then
    if [ "$YESTERDAY_DAY" -eq "$LAST_DAY_MONTH" ]; then
      log "[KEPT] $FILE_NAME (last day of month!)"
      echo "$FILE_NAME" >> "$TMP_KEPT"
    else
      log "[DELETED] $FILE_NAME (backup for $YESTERDAY)"
      aws $AWS_ARGS s3 rm "${S3_FULL_PATH}${FILE_NAME}" >>"$LOG_FILE" 2>&1
      echo "$FILE_NAME" >> "$TMP_REMOVED"
    fi
  fi
done

sleep 1

if [ -s "$TMP_REMOVED" ]; then
  log "Deleted files (for $YESTERDAY):"
  while read -r F; do log "  - $F"; done < "$TMP_REMOVED"
else
  log "No yesterday's files to delete (except month-end)."
fi

if [ -s "$TMP_KEPT" ]; then
  log "Kept backups for $YESTERDAY (latest of month):"
  while read -r F; do log "  - $F"; done < "$TMP_KEPT"
fi

rm -f "$TMP_REMOVED" "$TMP_KEPT"

log "=== S3 cleanup finished ==="