#!/bin/bash
set -e

BACKUP_FILE="$1"

if [ -z "$BACKUP_FILE" ]; then
  echo "Usage: ./restore.sh <backup_file.dump.gpg>"
  exit 1
fi

TMP_DUMP="/tmp/restore.dump"

# Decrypt backup
gpg --batch --yes --decrypt \
  --output "$TMP_DUMP" \
  "$BACKUP_FILE"

# Restore database
pg_restore \
  -h aws-1-eu-north-1.pooler.supabase.com \
  -p 5432 \
  -U postgres.bcweptazyanghinzmasl \
  -d postgres \
  --clean \
  --if-exists \
  "$TMP_DUMP"

# Cleanup
rm "$TMP_DUMP"
