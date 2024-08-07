#!/usr/bin/env bash

# Exit on error
set -e

# Default values
DEFAULT_INPUT_FILE="/initdb.json"
DEFAULT_DATA_FOLDER="/dbdata"
VERBOSE=false


INPUT_FILE="${DEFAULT_INPUT_FILE}"
DATA_FOLDER="${DEFAULT_DATA_FOLDER}"
NEXUS_BASE_URL=""
NEXUS_REPOSITORY=""
NEXUS_USERNAME=""
NEXUS_PASSWORD=""


SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")


# Include functions
source "$SCRIPT_DIR/include.functions.sh"


# Function to display the banner
display_banner() {
    _log "------------------------------------------"
    _log "- Mongo-Initializr - DbData Sync         "
    _log "------------------------------------------"
    _log
}

# Function to display script usage
display_help() {
    _log
    _log "Usage: $(basename -- $0) [OPTIONS]"
    _log "Options:"
    _log "  -i, --input-file [arg]     Specify input file (default: $DEFAULT_INPUT_FILE)"
    _log "  -d, --data-folder [arg]    Specify data folder (default: $DEFAULT_DATA_FOLDER)"
    _log
    _log "      --nexus-url [arg]      Specify Nexus base URL"
    _log "      --nexus-repo [arg]     Specify Nexus repository"
    _log "      --nexus-username [arg] Specify Nexus username"
    _log "      --nexus-password [arg] Specify Nexus password"
    _log
    _log "  -h, --help                 Display this help message"
    exit 1
}

# Function to parse all command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i|--input-file)
                INPUT_FILE="$2"
                shift 2
                ;;
            -d|--data-folder)
                DATA_FOLDER="$2"
                shift 2
                ;;
            --nexus-url)
                NEXUS_BASE_URL="$2"
                shift 2
                ;;
            --nexus-repo)
                NEXUS_REPOSITORY="$2"
                shift 2
                ;;
            --nexus-username)
                NEXUS_USERNAME="$2"
                shift 2
                ;;
            --nexus-password)
                NEXUS_PASSWORD="$2"
                shift 2
                ;;
            -h|--help)
                display_help
                ;;
            *)
                _log "Unknown option: $1"
                display_help
                ;;
        esac
    done
}

# Function for validating the command line arguments
validate_arguments() {
    # Check if all nexus settings are set
    if [ -z "$NEXUS_BASE_URL" ] || [ -z "$NEXUS_REPOSITORY" ] || [ -z "$NEXUS_USERNAME" ] || [ -z "$NEXUS_PASSWORD" ]; then
        _log "Error: Nexus URL, repository, username, and password are required."
        display_help
    fi

    # Check if initdb input file exists
    if [ ! -e "$INPUT_FILE" ]; then
        _log "Error: The input file '$INPUT_FILE' does not exist."
        display_help
    fi
}

# Function to get file checksum from Nexus
get_checksum_from_nexus() {
  local path=$1
  local url="$NEXUS_BASE_URL/service/rest/v1/search?repository=${NEXUS_REPOSITORY}&name=${path}"

  # Use curl and jq to get the checksum from Nexus API
  checksum=$(curl -s -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" -X GET "${url}" | jq -r '.items[0].assets[0].checksum.md5')

  echo $checksum
}

# Function to download file if not exists or changed
sync_file() {
  local path="$1.gz"
  local filename="${DATA_FOLDER}/${path}"
  local download=true

  # Check if the file exists locally
  if [ -e "$filename" ]; then
    remote_checksum=$(get_checksum_from_nexus "$path")
    local_checksum=$(md5sum "$filename" | awk '{print $1}')

    if [ "$remote_checksum" == "$local_checksum" ]; then
      _log "> Up-to-date"

      download=false
    fi
  fi

  # Download file from nexus if needed
  if [ "$download" = true ]; then
    # Make sure directory exists
    mkdir -p "$(dirname "$filename")"

    if [ "$VERBOSE" = true ]; then
        wget -O "$filename" --user="$NEXUS_USERNAME" --password="$NEXUS_PASSWORD" "$NEXUS_BASE_URL/repository/$NEXUS_REPOSITORY/$path"
    else
        wget -O "$filename" --quiet --user="$NEXUS_USERNAME" --password="$NEXUS_PASSWORD" "$NEXUS_BASE_URL/repository/$NEXUS_REPOSITORY/$path"
    fi

    _log "> Downloaded"
  fi

  # Uncompress the archive even if the uncompressed file allready exists
  gunzip --keep --force "$filename"

  _log "> Uncompressed"
}

# Function to add handle all entries in the input file
handle_input_file() {
    jq -c '.[]' "$INPUT_FILE" | while read object; do
        collection=$(echo "$object" | jq -r .collection)
        path=$(echo "$object" | jq -r .path)

        _log "Processing file '$path'"
        sync_file "$path"
    done
}


# Main script _logic
display_banner

parse_arguments "$@"

validate_arguments

_log "Handle inputfile '$INPUT_FILE'"
handle_input_file

_log "Done!"
