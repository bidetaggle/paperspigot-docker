#!/bin/bash

# Tweaks
NB_MAX_SNAPSHOTS=2
ROOT_DIRECTORY=/srv/paperspigot-docker

# Constants
SNAPSHOTS_DIRECTORY=.snapshots
PROD_DIR_PREFIX=/var/lib/docker/volumes/paperspigot-docker
CONTAINER_NAME=minecraft-db
DB_NAME=minecraft
DB_PWD=root
VOLUMES=(config worlds plugins data logs)

DATE=$(date '+%Y-%m-%d-%Hh%Mm%S')

function snapshot_server {
    cd $ROOT_DIRECTORY && docker-compose down
    echo "Starting server snapshot..."

    for volume in ${VOLUMES[*]}; do
        echo "Copying ${volume}..."
        cp -r ${PROD_DIR_PREFIX}_${volume}/_data $ROOT_DIRECTORY/$SNAPSHOTS_DIRECTORY/$DATE/${volume}
        if [ ! $? -eq 0 ]; then
            echo "Error when copying the volume ${volume}"
            exit 1
        else
            chown 1000:1000 ${PROD_DIR_PREFIX}_${volume}/_data -R
            echo "OK."
        fi
    done

    echo "Done."
    cd $ROOT_DIRECTORY && docker-compose up -d
}

function db_backup {
    echo "Exporting database from $CONTAINER_NAME to $ROOT_DIRECTORY/$SNAPSHOTS_DIRECTORY/$DATE/db.sql ..."
    docker exec -i $CONTAINER_NAME mysqldump --password=$DB_PWD $DB_NAME > $ROOT_DIRECTORY/$SNAPSHOTS_DIRECTORY/$DATE/db.sql
    
    if [ $? -eq 0 ]; then
        echo "Done."
    else
        echo "Error: Database backup failed."
        exit 1
    fi
}

function rolling_backups {
    echo "Starting rolling backup..."
    NB_SNAPSHOTS=($ROOT_DIRECTORY/$SNAPSHOTS_DIRECTORY/*)

    if [ ${#NB_SNAPSHOTS[@]} -gt $NB_MAX_SNAPSHOTS ] ; then
        echo "Deleting the oldest snapshot"
        rm -rf $ROOT_DIRECTORY/$SNAPSHOTS_DIRECTORY/$(ls -F $ROOT_DIRECTORY/$SNAPSHOTS_DIRECTORY | head -n 1)
    else
        echo "The number of snapshots does not exceed the maximum set (${#NB_SNAPSHOTS[@]}/$NB_MAX_SNAPSHOTS). Rolling nothing."
    fi
}

function on_exit {
    if [ ! $? -eq 0 ]; then
        echo "Something went wrong :( , cleaning up."
        rm -rf $ROOT_DIRECTORY/$SNAPSHOTS_DIRECTORY/$(ls -F $ROOT_DIRECTORY/$SNAPSHOTS_DIRECTORY | head -n 1)
    else
        echo "Done."
    fi
}

mkdir -p $ROOT_DIRECTORY/$SNAPSHOTS_DIRECTORY/$DATE
trap on_exit EXIT

db_backup
snapshot_server
rolling_backups
