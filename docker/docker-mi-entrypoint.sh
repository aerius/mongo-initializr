#!/usr/bin/env bash
set -Eeuo pipefail

MI_ENTRYPOINT_DB_DIRECTORY=/data/db
MI_ENTRYPOINT_DB_PREVIOUS_FILES_HASH_FILE="${MI_ENTRYPOINT_DB_DIRECTORY}"/mi.previous_files_hash

# Only if the appropriate properties are set will we do a wipe
if [[ "${MI_ENTRYPOINT_WIPE_DB_ON_CHANGES}" == 'true' ]]; then
  # Do some sanity checks to see a mongo DB is present in the expected place before wiping
  # These are the same files the mongo entrypoint checks on before running the initdb step.
  if [[ -f "${MI_ENTRYPOINT_DB_DIRECTORY}"/WiredTiger && -d "${MI_ENTRYPOINT_DB_DIRECTORY}"/journal && -f "${MI_ENTRYPOINT_DB_DIRECTORY}"/storage.bson ]]; then
    PREVIOUS_FILES_HASH=
    [[ -f "${MI_ENTRYPOINT_DB_PREVIOUS_FILES_HASH_FILE}" ]] && PREVIOUS_FILES_HASH=$(<"${MI_ENTRYPOINT_DB_PREVIOUS_FILES_HASH_FILE}")

    # If files hash is different, remove files echoing explicitly what is removed
    if [[ "${PREVIOUS_FILES_HASH}" != "${MI_ENTRYPOINT_CURRENT_FILES_HASH}" ]]; then
      echo '# Files hash has changed, wiping old data..'
      rm -rfv "${MI_ENTRYPOINT_DB_DIRECTORY}"/*
    else
      echo '# Files hash has not changed.. Will not wipe old data..'
    fi

  else
    echo '# WARNING: Wipe on DB changes is enabled, but I could not find the proper files.. Skipping wipe..'
  fi

  # Store the current hash
  echo "${MI_ENTRYPOINT_CURRENT_FILES_HASH}" > "${MI_ENTRYPOINT_DB_PREVIOUS_FILES_HASH_FILE}"
fi

# Execute default mongo entrypoint
exec docker-entrypoint.sh "${@}"
