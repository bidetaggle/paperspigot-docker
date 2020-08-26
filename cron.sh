#!/bin/bash

# Tweaks
NB_MAX_SNAPSHOTS=2

# Constants
SNAPSHOTS_DIRECTORY=snapshots
PROD_DIRECTORY=/var/lib/docker/volumes/paperspigot-docker_server/_data
CONTAINER_NAME=minecraft-db
DB_NAME=minecraft_267223
DB_PWD=root

DATE=$(date '+%Y-%m-%d-%Hh%Mm%S')

function snapshot_server {
    docker-compose down
    echo "Starting server snapshot..."

    cp -r $PROD_DIRECTORY $SNAPSHOTS_DIRECTORY/$DATE/root

    if [ $? -eq 0 ]; then
        echo "Done."
        docker-compose up -d
    else
        echo "Error: Server backup failed."
        exit 1
    fi
}

function db_backup {
    echo "Starting database backup..."
    docker exec $CONTAINER_NAME mysqldump --password=$DB_PWD $DB_NAME > $SNAPSHOTS_DIRECTORY/$DATE/db.sql
    
    if [ $? -eq 0 ]; then
        echo "Done."
    else
        echo "Error: Database backup failed."
        exit 1
    fi
}

function rolling_backups {
    NB_SNAPSHOTS=($SNAPSHOTS_DIRECTORY/*)

    if [ ${#NB_SNAPSHOTS[@]} -gt $NB_MAX_SNAPSHOTS ] ; then
        rm -rf $SNAPSHOTS_DIRECTORY/$(ls -F $SNAPSHOTS_DIRECTORY | head -n 1)
    fi
}

mkdir $SNAPSHOTS_DIRECTORY/$DATE
db_backup
snapshot_server
rolling_backups
