#!/bin/bash
set -Eeuo pipefail

# Change current directory to directory of script so it can be called from everywhere
SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")
cd "${SCRIPT_DIR}"

# Mongo versions
IMAGE_VERSIONS=(
  "8.0.6"
)

# Read in current version of the script
BUILD_VERSION=$(<VERSION)

for MONGO_VERSION in "${IMAGE_VERSIONS}"; do
  echo "# Processing - Mongo: ${MONGO_VERSION}"
  IMAGE_TAG="${BUILD_VERSION}-${MONGO_VERSION}"

  # Create directory if it doesn't exist yet
  if [[ ! -d "${IMAGE_TAG}" ]]; then
    mkdir -p "docker/${IMAGE_TAG}"
  fi

  # Copy over files and process templates
  sed -e 's/%%MONGO_VERSION%%/'"${MONGO_VERSION}"'/g;' \
      docker/Dockerfile.template > "docker/${IMAGE_TAG}/Dockerfile"
done
