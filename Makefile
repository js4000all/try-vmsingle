VM_DATA_DIR := /srv/volumes/try-vmsingle/vmsingle/vmdata

.PHONY: up down ps logs prepare-dirs reset clear-vmsingle build test generate duckdb duckdb-r2 duckdb-layout duckdb-layout-large

# Create (or verify) the host directory with permissions for UID/GID 1000.
# sudo may prompt for a password.
prepare-dirs:
	sudo install -d -o 1000 -g 1000 -m 0755 "$(VM_DATA_DIR)"

build:
	mkdir -p bin
	docker compose build go-builder
	docker compose run --rm --no-deps --user "$$(id -u):$$(id -g)" -e GOCACHE=/tmp/go-build -e GOPATH=/tmp/go go-builder go build -o /out/sample-generator ./cmd/sample-generator

test:
	docker compose build go-builder
	docker compose run --rm --no-deps --user "$$(id -u):$$(id -g)" -e GOCACHE=/tmp/go-build -e GOPATH=/tmp/go go-builder go test ./...

# Run generated Linux binary directly on the host (does not rebuild).
generate:
	./bin/sample-generator

# Destructive operation: asks for the literal DELETE before clearing.
clear-vmsingle:
	sh scripts/clear-vmsingle.sh

up: prepare-dirs
	docker compose up -d

down:
	docker compose down

ps:
	docker compose ps

logs:
	docker compose logs -f vmsingle otel-collector

# Stop and remove containers only. Bind-mounted host data is preserved.
reset:
	docker compose down -v

# Start an ephemeral interactive DuckDB CLI; workspace files persist on host.
duckdb:
	mkdir -p work/duckdb
	docker compose run --rm --no-deps --user "$$(id -u):$$(id -g)" duckdb

# Prepare a session-only R2 secret (credentials arrive via environment variables).
duckdb-r2:
	sh scripts/prepare-duckdb-r2.sh
	docker compose run --rm --no-deps --user "$$(id -u):$$(id -g)" duckdb

# Create destination directories and start DuckDB for local layout experiments.
duckdb-layout:
	mkdir -p work/duckdb/layout-test/long work/duckdb/layout-test/wide work/duckdb/layout-test/hive
	docker compose run --rm --no-deps --user "$$(id -u):$$(id -g)" duckdb

# Generate a full month of synthetic time-series data using DuckDB.
duckdb-layout-large:
	mkdir -p work/duckdb/layout-large
	docker compose run --rm --no-deps --user "$$(id -u):$$(id -g)" duckdb
