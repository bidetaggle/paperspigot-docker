#!/bin/bash

docker-compose down

MAX_NB_BACKUPS=2
BACKUPS_DIRECTORY=backups

DATE=$(date '+%Y-%m-%d-%Hh%Mm%S')

echo -e "\033[41mStarting backup at $BACKUPS_DIRECTORY/$DATE \033[0m"

mkdir $BACKUPS_DIRECTORY/$DATE
cp -r /var/lib/docker/volumes/paperspigot-docker_worlds/_data $BACKUPS_DIRECTORY/$DATE/worlds

NB_BACKUPS=($BACKUPS_DIRECTORY/*)

if [ ${#NB_BACKUPS[@]} -gt $MAX_NB_BACKUPS ] 
then
    OLD_BACKUP=$(ls -F backups | head -n 1)
    rm -rf $BACKUPS_DIRECTORY/$OLD_BACKUP
fi

echo "Backup done."

docker-compose up -d
