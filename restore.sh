#!/bin/bash

BASH_NAME="./restore.sh"
SNAPSHOTS_DIRECTORY=snapshots
PROD_DIRECTORY=/var/lib/docker/volumes/paperspigot-docker_server/_data

function display_usage {
    echo "Usage: ./restore.sh <Days(number)|confirm|cancel|status>" >&2
    echo "Exemples:"
    echo " - restore from yesterday and confirm:"
    echo "    ./restore.sh 1"
    echo "    ./restore.sh confirm"
    echo " - restore from 2 days ago but you changed your mind and cancel:"
    echo "    ./restore.sh 2"
    echo "    ./restore.sh cancel"
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

    docker-compose down
    
    date=$(date '+%Y-%m-%d-%Hh%Mm%S')

    if [ ! -d $SNAPSHOTS_DIRECTORY/*_original ]; then
        print_warning "Initializing restoration process..."
        mkdir $SNAPSHOTS_DIRECTORY/${date}_original
        mv /var/lib/docker/volumes/paperspigot-docker_server/_data/* $SNAPSHOTS_DIRECTORY/${date}_original
    else
        print_warning "Restoration already initialized."
    fi
    
    to_restore=$(ls -F $SNAPSHOTS_DIRECTORY | tail -n $(($1 + 1)) | head -n 1)
    print_info "Copying ./$SNAPSHOTS_DIRECTORY/$to_restore content ..."

    rm -rf $PROD_DIRECTORY/*
    cp -r -a $SNAPSHOTS_DIRECTORY/$to_restore/* $PROD_DIRECTORY

    if [ $? -eq 0 ]; then
        print_info "Done."
        docker-compose up -d

        echo ""
        print_info "Server is now running on snapshot $to_restore [$1 day(s) ago]"
        echo ""
        print_info "To finalize restoration, please launch one of the following commands:"
        echo "$ $BASH_NAME confirm"
        echo "$ $BASH_NAME cancel"
        echo ""
        echo "You can keep trying other snapshots before finalizing the restoration:"
        echo "$ $BASH_NAME <day(s) ago>"
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

    docker-compose down

    print_info "Bringing back the original directory..."

    rm -rf $PROD_DIRECTORY/*
    cp -r -a $SNAPSHOTS_DIRECTORY/*_original/* $PROD_DIRECTORY
    
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

    if [ $? -eq 0 ]; then
        print_info "Done."
        docker-compose up -d
    else
        print_error "Something wrong happened :("
    fi
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
else
    print_error "I don't understand :s"
    display_usage
    exit 1 
fi

