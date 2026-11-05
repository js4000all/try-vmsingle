#!/bin/sh
set -eu

DATA_DIR="/srv/volumes/try-vmsingle/vmsingle/vmdata"

if [ ! -d "$DATA_DIR" ] || [ -L "$DATA_DIR" ]; then
  echo "Refusing: data directory is missing or a symlink: $DATA_DIR" >&2
  exit 1
fi
actual=$(realpath -- "$DATA_DIR")
if [ "$actual" != "$DATA_DIR" ]; then
  echo "Refusing: unexpected canonical data directory: $actual" >&2
  exit 1
fi
if mountpoint -q "$DATA_DIR"; then
  echo "Refusing: data directory is a mount point" >&2
  exit 1
fi
printf 'This will permanently delete ALL files under %s\n' "$DATA_DIR"
printf 'Type DELETE to proceed: '
IFS= read -r answer
if [ "$answer" != "DELETE" ]; then
  echo "Cancelled."
  exit 1
fi

docker compose down
# Use sudo only for deleting the contents of the verified fixed directory.
sudo find "$DATA_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
echo "Local vmsingle data cleared. Run make up to start services."
