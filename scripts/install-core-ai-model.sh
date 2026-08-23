#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 /path/to/exported-model-folder" >&2
  exit 64
fi

SOURCE_DIR=$1
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(dirname -- "$SCRIPT_DIR")
DESTINATION="${PROJECT_DIR}/Resources/CoreAI"

if [ ! -f "${SOURCE_DIR}/metadata.json" ]; then
  echo "Expected ${SOURCE_DIR}/metadata.json" >&2
  exit 66
fi

if ! find "${SOURCE_DIR}" -maxdepth 1 -name '*.aimodel' -type d | grep -q .; then
  echo "Expected an .aimodel directory in ${SOURCE_DIR}" >&2
  exit 66
fi

mkdir -p "${DESTINATION}"
rsync -a \
  --exclude '.git' \
  --exclude '.DS_Store' \
  "${SOURCE_DIR}/" "${DESTINATION}/"

echo "Installed Core AI resources in ${DESTINATION}"
echo "Regenerate the project with: xcodegen generate"
