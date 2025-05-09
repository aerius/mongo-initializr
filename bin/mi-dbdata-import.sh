#!/usr/bin/env bash

# Exit on error
set -e

# Default values
DEFAULT_INPUT_FILE="/initdb.json"
DEFAULT_DATA_FOLDER="/dbdata"
DEFAULT_MONGO_HOST="localhost"
DEFAULT_MONGO_PORT="27017"


INPUT_FILE="${DEFAULT_INPUT_FILE}"
DATA_FOLDER="${DEFAULT_DATA_FOLDER}"
MONGO_HOST="${DEFAULT_MONGO_HOST}"
MONGO_PORT="${DEFAULT_MONGO_PORT}"
MONGO_USER=""
MONGO_PASS=""
MONGO_IMPORT_NUM_INSERTION_WORKERS=1
DATABASE_NAME=""
DATABASE_VERSION=""


SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")


# Include functions
source "${SCRIPT_DIR}/include.functions.sh"


# Function to display the banner
display_banner() {
    _log "------------------------------------------"
    _log "- Mongo-Initializr - DbData Import        "
    _log "------------------------------------------"
    _log
}

# Function to display script usage
display_help() {
    _log
    _log "Usage: $(basename -- $0) [OPTIONS]"
    _log "Options:"
    _log "  -i, --input-file [arg]        Specify input file (default: ${DEFAULT_INPUT_FILE})"
    _log "  -d, --data-folder [arg]       Specify data folder (default: ${DEFAULT_DATA_FOLDER})"
    _log
    _log "      --mongo-hostname [arg]    Specify MongoDB hostname (default: ${DEFAULT_MONGO_HOST})"
    _log "      --mongo-port [arg]        Specify MongoDB port (default: ${DEFAULT_MONGO_PORT})"
    _log "      --mongo-username [arg]    Specify MongoDB username"
    _log "      --mongo-password [arg]    Specify MongoDB password"
    _log
    _log "      --database-name [arg]     Specify database name"
    _log "      --database-version [arg]  Specify database version"
    _log
    _log "      --insertion-workers [arg] Specify amount of insertion workers to use (default: ${MONGO_IMPORT_NUM_INSERTION_WORKERS})"
    _log
    _log "  -h, --help                    Display this help message"
    exit 1
}

# Function to parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -i|--input-file)
                INPUT_FILE="$2"
                shift 2
                ;;
            -d|--data-folder)
                DATA_FOLDER="$2"
                shift 2
                ;;
            --mongo-host)
                MONGO_HOST="$2"
                shift 2
                ;;
            --mongo-port)
                MONGO_PORT="$2"
                shift 2
                ;;
            --mongo-username)
                MONGO_USER="$2"
                MONGO_NOAUTH=false
                shift 2
                ;;
            --mongo-password)
                MONGO_PASS="$2"
                shift 2
                ;;
            --database-name)
                DATABASE_NAME="$2"
                shift 2
                ;;
            --database-version)
                DATABASE_VERSION="$2"
                shift 2
                ;;
            --insertion-workers)
                MONGO_IMPORT_NUM_INSERTION_WORKERS="$2"
                shift 2
                ;;
            -h|--help)
                display_help
                ;;
            *)
                _log "Unknown option: ${1}"
                display_help
                ;;
        esac
    done
}

# Function for validating the command line arguments
validate_arguments() {
    # Check if all mongo settings are set
    if [[ -z "${MONGO_USER}" ]] || [[ -z "${MONGO_PASS}" ]]; then
        _log "Error: Mongo credentials are required."
        display_help
    fi

    # Check if database-name / -version are set
    if [[ -z "${DATABASE_NAME}" ]] || [[ -z "${DATABASE_VERSION}" ]]; then
        _log "Error: Database name and version are required."
        display_help
    fi

    # Check if initdb input file exists
    if [[ ! -f "${INPUT_FILE}" ]]; then
        _log "Error: The input file '${INPUT_FILE}' does not exist."
        display_help
    fi
}

# Function to clean a MongoDB database
clean_database() {
    _mongosh --eval "db.getCollectionNames().forEach(function(n){db[n].drop({})});"
}

# Function to add handle all entries in the input file
handle_input_file() {
    jq -r '.[] | "\(.collection) \(.path)"' "${INPUT_FILE}" | while read collection path; do
        add_json_to_collection "${collection}" "${path}"
    done
}

# Function to add JSON data to a collection
add_json_to_collection() {
    local collection=${1}
    local filename="${DATA_FOLDER}/${2}"

    _log "Processing file '${2}'."

    # Check if the JSON filename exists
    if [[ -f "${filename}" ]]; then
        # Add JSON data to the collection. Use mongoimport to create the collection and add data
        _mongoimport --numInsertionWorkers "${MONGO_IMPORT_NUM_INSERTION_WORKERS}" --collection ${collection} --file $filename --jsonArray --upsert --upsertFields "_id"

        _log "'${filename}' is added to '${collection}'"
    else
        _log "Error: JSON file '$filename' not found."
        exit 1
    fi
}

# Function to add the constants to the database
add_constants() {
    constants=$(jq -n -c --arg name "${DATABASE_NAME}" --arg version "${DATABASE_VERSION}" \
    '{
      _id: 1,
      database: $ARGS.named
    }')
    _mongosh --eval "db.constants.insertOne(${constants})"
}


# Main script logic
display_banner

parse_arguments "$@"

validate_arguments

_log "Clean database '${DATABASE_NAME}'"
clean_database

_log "Handle inputfile '${INPUT_FILE}'"
handle_input_file

_log "Add constants to database '${DATABASE_NAME}'"
add_constants

_log "Done!"
