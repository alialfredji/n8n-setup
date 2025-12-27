#!/bin/bash
set -euo pipefail

BACKUP_DIR="/root/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/n8n_backup_$TIMESTAMP.sql.gz"
RETENTION_DAYS=30

# Load environment variables
if [ -f /root/.env ]; then
    source /root/.env
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "Starting backup at $(date)"

# Backup PostgreSQL database
docker exec n8n_postgres pg_dump -U "${POSTGRES_USER}" "${POSTGRES_DB}" | gzip > "$BACKUP_FILE"
echo "Database backup completed: $BACKUP_FILE"

# Backup n8n data volume
docker run --rm -v n8n_data:/data -v "$BACKUP_DIR:/backup" alpine tar czf "/backup/n8n_data_$TIMESTAMP.tar.gz" -C /data .
echo "n8n data backup completed: n8n_data_$TIMESTAMP.tar.gz"

# Delete old backups
find "$BACKUP_DIR" -name "n8n_backup_*.sql.gz" -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR" -name "n8n_data_*.tar.gz" -mtime +$RETENTION_DAYS -delete
echo "Old backups cleaned up (retention: $RETENTION_DAYS days)"

echo "Backup completed successfully at $(date)"

