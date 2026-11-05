#!/bin/sh
set -eu

# Load the local developer-owned dotenv file. Never commit .env.
if [ ! -f .env ]; then
  echo "Missing .env. Copy .env.example to .env and set the R2 credentials." >&2
  exit 1
fi
set -a
. ./.env
set +a

: "${R2_ACCOUNT_ID:?Set R2_ACCOUNT_ID in .env}"
: "${R2_BUCKET:?Set R2_BUCKET in .env}"
: "${R2_ACCESS_KEY_ID:?Set R2_ACCESS_KEY_ID in .env}"
: "${R2_SECRET_ACCESS_KEY:?Set R2_SECRET_ACCESS_KEY in .env}"

# Only a 32-character hexadecimal account ID is accepted before generating SQL.
case "$R2_ACCOUNT_ID" in
  *[!0123456789abcdefABCDEF]*) echo "Invalid R2_ACCOUNT_ID" >&2; exit 1 ;;
esac
if [ "${#R2_ACCOUNT_ID}" -ne 32 ]; then
  echo "R2_ACCOUNT_ID must be 32 hex characters" >&2
  exit 1
fi

mkdir -p work/duckdb
cat > work/duckdb/r2-init.sql <<EOF
INSTALL httpfs;
LOAD httpfs;
INSTALL aws;
LOAD aws;

CREATE OR REPLACE SECRET r2_connection (
    TYPE r2,
    PROVIDER credential_chain,
    CHAIN 'env',
    ACCOUNT_ID '$R2_ACCOUNT_ID'
);
EOF
echo "Created work/duckdb/r2-init.sql (no access key or secret stored)."
echo "Start DuckDB and run: .read /workspace/r2-init.sql"
