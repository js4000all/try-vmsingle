#!/bin/sh
set -eu

VM_URL="http://127.0.0.1:8428"
MATCHER='{__name__=~".+"}'

command -v curl >/dev/null 2>&1 || {
  echo "curl is required" >&2
  exit 1
}

curl --fail --silent --show-error --max-time 10 "$VM_URL/health" >/dev/null

printf 'Delete ALL time series (all metrics, all dates) in %s?\n' "$VM_URL"
printf 'This cannot be undone. Type DELETE to confirm: '
IFS= read -r answer || exit 1
if [ "$answer" != "DELETE" ]; then
  echo "Cancelled."
  exit 1
fi

curl --fail --silent --show-error --max-time 120 \
  -X POST "$VM_URL/api/v1/admin/tsdb/delete_series" \
  --data-urlencode "match[]=$MATCHER"

echo "Delete request succeeded. No files or directories were removed."
echo "Disk usage may decrease only after background merges."
