#!/bin/bash

docker-compose down

NB_MAX_SNAPSHOTS=2
SNAPSHOTS_DIRECTORY=snapshots
DATE=$(date '+%Y-%m-%d-%Hh%Mm%S')

echo "Starting backup..."

cp -r /var/lib/docker/volumes/paperspigot-docker_server/_data/ $SNAPSHOTS_DIRECTORY/$DATE

if [ $? -eq 0 ]
then
    NB_SNAPSHOTS=($SNAPSHOTS_DIRECTORY/*)

    if [ ${#NB_SNAPSHOTS[@]} -gt $NB_MAX_SNAPSHOTS ] ; then
        rm -rf $SNAPSHOTS_DIRECTORY/$(ls -F $SNAPSHOTS_DIRECTORY | head -n 1)
    fi

    echo -e "\e[34mBackup done.\e[39m"
    docker-compose up -d
else
    echo -e "\e[91mImpossible to backup, operation stalled"
fi
