# postgres-backup-s3

Backup PostgresSQL to S3 (supports periodic backups)

This is a fork of [karser/postgres-backup-s3](https://github.com/karser/docker-images) with http://healthchecks.io support

## Usage

Docker:
```sh
$ docker run -e S3_ACCESS_KEY_ID=key -e S3_SECRET_ACCESS_KEY=secret -e S3_BUCKET=my-bucket -e S3_PREFIX=backup -e POSTGRES_DATABASE=dbname -e POSTGRES_USER=user -e POSTGRES_PASSWORD=password -e POSTGRES_HOST=localhost f213/postgres-backup-s3
```

Docker Compose:
```yaml
postgres:
  image: postgres
  environment:
    POSTGRES_USER: user
    POSTGRES_PASSWORD: password

postgres-backup:
  image: f213/postgres-backup-s3
  links:
    - postgres
  healthcheck:
    test: curl http://localhost:1880

  environment:
    SCHEDULE: 0 30 */2 * * *  # every 2 hours at HH:30
    S3_REGION: region
    S3_ACCESS_KEY_ID: key
    S3_SECRET_ACCESS_KEY: secret
    S3_BUCKET: my-bucket
    S3_PREFIX: backup
    POSTGRES_HOST: localhost
    POSTGRES_DATABASE: dbname
    POSTGRES_USER: user
    POSTGRES_PASSWORD: password
    POSTGRES_EXTRA_OPTS: '--schema=public --blobs'
    HEALTHCHECKS_IO_CHECK_ID: 73968bba-011a-476b-b206-7b113af22e0c
```

### Automatic Periodic Backups

You can additionally set the `SCHEDULE` environment variable like `-e SCHEDULE="@daily"` to run the backup automatically.

More information about the scheduling can be found [here](http://godoc.org/github.com/robfig/cron#hdr-Predefined_schedules).
