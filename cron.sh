#!/bin/bash

# Tweaks
NB_MAX_SNAPSHOTS=2

# Constants
SNAPSHOTS_DIRECTORY=snapshots
PROD_DIR_PREFIX=/var/lib/docker/volumes/paperspigot-docker
CONTAINER_NAME=minecraft-db
DB_NAME=minecraft
DB_PWD=root
VOLUMES=(config worlds plugins data logs)

DATE=$(date '+%Y-%m-%d-%Hh%Mm%S')

function snapshot_server {
    docker-compose down
    echo "Starting server snapshot..."

    for volume in ${VOLUMES[*]}; do
        echo "Copying ${volume}..."
        cp -r ${PROD_DIR_PREFIX}_${volume}/_data $SNAPSHOTS_DIRECTORY/$DATE/${volume}
        if [ ! $? -eq 0 ]; then
            echo "Error when copying the volume ${volume}"
            exit 1
        else
            echo "OK."
        fi
    done

    echo "Done."
    docker-compose up -d
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
    echo "Starting rolling backup..."
    NB_SNAPSHOTS=($SNAPSHOTS_DIRECTORY/*)

    if [ ${#NB_SNAPSHOTS[@]} -gt $NB_MAX_SNAPSHOTS ] ; then
        echo "Deleting the oldest snapshot"
        rm -rf $SNAPSHOTS_DIRECTORY/$(ls -F $SNAPSHOTS_DIRECTORY | head -n 1)
    fi
}

mkdir $SNAPSHOTS_DIRECTORY/$DATE
db_backup
snapshot_server
rolling_backups
