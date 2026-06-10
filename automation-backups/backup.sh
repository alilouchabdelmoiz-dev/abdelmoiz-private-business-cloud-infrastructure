#!/bin/bash

# Configuration variables
BACKUP_DIR="/media/backup-usb/svr01-backups"
LOG_FILE="/var/log/svr01-backup.log"
DATE=$(date '+%Y-%m-%d_%H-%M-%S')

# Ensure backup destination directory exists
mkdir -p "$BACKUP_DIR"

echo "=== Backup Started at $DATE ===" >> "$LOG_FILE"

# Backup system rules (/etc) and your active container data using exact paths
sudo rsync -avz --delete /etc "$BACKUP_DIR/" >> "$LOG_FILE" 2>&1
sudo rsync -avz --delete /home/vmadmin/data/ "$BACKUP_DIR/data/" >> "$LOG_FILE" 2>&1

if [ $? -eq 0 ]; then
    echo "=== Backup Completed Successfully at $(date '+%Y-%m-%d_%H-%M-%S') ===" >> "$LOG_FILE"
else
    echo "!!! Backup FAILED at $(date '+%Y-%m-%d_%H-%M-%S') !!!" >> "$LOG_FILE"
fi

echo "----------------------------------------" >> "$LOG_FILE"
