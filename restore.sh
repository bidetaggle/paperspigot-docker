#!/bin/bash

BASH_NAME="./restore.sh"
SNAPSHOTS_DIRECTORY=.snapshots
PROD_DIRECTORY=/var/lib/docker/volumes/paperspigot-docker
CONTAINER_NAME=minecraft-db
DB_NAME=minecraft
DB_USER=root
DB_PWD=root
VOLUMES=(config worlds plugins data logs)

function display_usage {
    echo "Usage: ./restore.sh <Days(number)|confirm|cancel|status|> | <*.sql>" >&2
    echo "Exemples:"
    echo " - restore from yesterday and confirm:"
    echo "    ./restore.sh 1"
    echo "    ./restore.sh confirm"
    echo " - restore from 2 days ago but you changed your mind and cancel:"
    echo "    ./restore.sh 2"
    echo "    ./restore.sh cancel"
    echo ""
    echo "Import a local sql file to the running $CONTAINER_NAME container:"
    echo "./restore.sh your-file.sql"
}

function print_error {
    echo ""
    echo -e "\e[91m${1}\e[39m"
    echo ""
}
function print_info {
    echo -e "\e[36m${1}\e[39m"
}
function print_warning {
    echo -e "\e[93m${1}\e[39m"
}

function get_status {
    if [ -d $SNAPSHOTS_DIRECTORY/*_original ]; then
        echo "Restoration initialized. Please confirm or cancel to finish restoration properly."
    else
        echo "Ready to start restoration"
    fi
}

function assess {
    command_result=$1
    if [ $command_result -eq 0 ]; then
        print_info "Done."
    else
        print_error "Failed :("
        exit 1
    fi
}

function restore_db_from {
    sql_path=${SNAPSHOTS_DIRECTORY}/${1}db.sql
    
    print_info "Cleaning up db..." 
    docker exec $CONTAINER_NAME mysql --password=$DB_PWD -e "DROP DATABASE $DB_NAME; CREATE DATABASE $DB_NAME" $DB_NAME
    assess $?

    print_info "Import db from ${sql_path} ..."
    docker exec -i $CONTAINER_NAME mysql --password=$DB_PWD -u $DB_USER $DB_NAME < ${sql_path}
    assess $?
}

function restore {
    ls_snapshots=($SNAPSHOTS_DIRECTORY/*)
    nb_snapshots=${#ls_snapshots[@]}

    if [ -d $SNAPSHOTS_DIRECTORY/*_original ]; then
        nb_snapshots=$((nb_snapshots - 1))
    fi

    if [ ! $1 -le $nb_snapshots ]; then
        print_error "There is only $((${nb_snapshots})) snapshot(s) available."
        exit 1
    fi

    to_restore=$(ls -F $SNAPSHOTS_DIRECTORY | tail -n $(($1 + 1)) | head -n 1)
    date=$(date '+%Y-%m-%d-%Hh%Mm%S')

    if [ ! -d $SNAPSHOTS_DIRECTORY/*_original ]; then
        print_warning "Initializing restoration process..."
        
        print_info "Export db..."
        mkdir $SNAPSHOTS_DIRECTORY/${date}_original
        docker exec $CONTAINER_NAME mysqldump --password=$DB_PWD $DB_NAME > $SNAPSHOTS_DIRECTORY/${date}_original/db.sql
        assess $?

        restore_db_from $to_restore

        docker-compose down

        for volume in ${VOLUMES[*]}; do
            print_info "Moving ${volume} out of the way..."
            mkdir $SNAPSHOTS_DIRECTORY/${date}_original/$volume
            mv /var/lib/docker/volumes/paperspigot-docker_${volume}/_data/* $SNAPSHOTS_DIRECTORY/${date}_original/${volume}
            if [ ! $? -eq 0 ]; then
                print_error "Error when moving this Docker volume to $SNAPSHOTS_DIRECTORY/${date}_original/${volume}"
                exit 1
            else
                print_info "OK."
            fi
        done
    else
        print_warning "Restoration already initialized."
        restore_db_from $to_restore
        docker-compose down
    fi

    print_info "Copying ./$SNAPSHOTS_DIRECTORY/$to_restore content ..."

    for volume in ${VOLUMES[*]}; do

        print_info "Cleaning up $volume volume..."   
        
        rm -rf ${PROD_DIRECTORY}_${volume}/_data/*
        if [ ! $? -eq 0 ]; then
            print_error "Error when copying $SNAPSHOTS_DIRECTORY/$to_restore/${volume} to /var/lib/docker/volumes/paperspigot-docker  _${volume}/_data/"
            exit 1
        else
            print_info "OK."
        fi
        
        print_info "Copying ${volume}..."
       
        cp -r -a $SNAPSHOTS_DIRECTORY/$to_restore/${volume}/* /var/lib/docker/volumes/paperspigot-docker_${volume}/_data
        if [ ! $? -eq 0 ]; then
            print_error "Error when copying $SNAPSHOTS_DIRECTORY/$to_restore/${volume} to /var/lib/docker/volumes/paperspigot-docker_${volume}/_data/"
            exit 1
        else
            print_info "OK."
        fi
    done

    if [ $? -eq 0 ]; then
        print_info "Done."
        docker-compose up -d

        echo ""
        print_info "Server is now running on snapshot $to_restore [$1 day(s) ago]"
        echo ""
        print_info "To finalize restoration, please launch one of the following commands:"
        print_info "$ $BASH_NAME confirm"
        print_info "$ $BASH_NAME cancel"
        echo ""
        print_info "You can keep trying other snapshots before finalizing the restoration:"
        print_info "$ $BASH_NAME <day(s) ago>"
        echo ""
    else
        print_error "Something wrong happened :("
    fi
}

function cancel {
    # check for restoration status
    if [ ! -d $SNAPSHOTS_DIRECTORY/*_original ]; then
        print_error "There is nothing to cancel."
        display_usage
        exit 1
    fi

    restore_db_from *_original/

    docker-compose down

    print_info "Bringing back the original directory..."

    for volume in ${VOLUMES[*]}; do

        print_info "Deleting ${volume} content..."
        
        rm -rf ${PROD_DIRECTORY}_${volume}/_data/*
        if [ $? -eq 0 ]; then
            print_info "OK."
        else
            print_error "Something wrong happened :s"
        fi

        print_info "Bringing back original ${volume}"
        
        cp -r -a $SNAPSHOTS_DIRECTORY/*_original/* /var/lib/docker/volumes/paperspigot-docker_${volume}/_data/
        if [ $? -eq 0 ]; then
             print_info "OK."
        else
             print_error "Something wrong happened :s"
        fi
    done
    
    if [ $? -eq 0 ]; then
        print_info "Cleaning up..."
        rm -rf $SNAPSHOTS_DIRECTORY/*_original
        if [ $? -eq 0 ]; then
            print_info "Done."
            docker-compose up -d
        else
            print_error "Something wrong happened."
        fi
    else
        print_error "Something wrong happened :("
    fi
}

function confirm {
    # check for Restoration status
    if [ ! -d $SNAPSHOTS_DIRECTORY/*_original ]; then
        print_error "There is nothing to confirm."
        display_usage
        exit 1
    fi

    docker-compose down

    print_info "Cleaning up original directory..."
    rm -rf $SNAPSHOTS_DIRECTORY/*_original
    assess $?
    
    docker-compose up -d
}

function migrate_db {
    # check for restoration status
    if [ -d $SNAPSHOTS_DIRECTORY/*_original ]; then
        print_error "Snapshot restoration started already."
        print_info "Please confirm or cancel to properly finish the restoration."
        echo ""
        display_usage
        exit 1
    fi

    sql_file=$1

    print_info "Cleaning up db..."
    docker exec $CONTAINER_NAME mysql -u $DB_USER --password=$DB_PWD $DB_NAME -e "DROP DATABASE minecraft; CREATE DATABASE minecraft"
    assess $?

    print_info "Import $sql_file (host) to minecraft container"
    docker exec -i $CONTAINER_NAME mysql -u $DB_USER --password=$DB_PWD $DB_NAME < $sql_file
    assess $?
}

# Args match
if [[ $1 = 'status' ]]; then
    get_status
elif [[ $1 =~ $(echo '^[0-9]+$') ]]; then
    restore $1
elif [[ $1 = 'cancel' ]]; then
    cancel
elif [[ $1 = 'confirm' ]]; then
    confirm
elif [[ "$1" == *\.sql ]]; then
    migrate_db $1
else
    print_error "I don't understand :s"
    display_usage
    exit 1 
fi

