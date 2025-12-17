#!/bin/bash
set -e

DATE=$(date +%F)

# Directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Store backups next to the project, not inside it
BACKUP_DIR="$SCRIPT_DIR/../supabase_backups"
FILE="$BACKUP_DIR/backup_$DATE.dump"

mkdir -p "$BACKUP_DIR"

pg_dump \
  -h aws-1-eu-north-1.pooler.supabase.com \
  -p 5432 \
  -U postgres.bcweptazyanghinzmasl \
  -d postgres \
  -F c \
  -f "$FILE"

gpg --batch --yes --symmetric --cipher-algo AES256 "$FILE"
rm "$FILE"
