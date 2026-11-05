VM_DATA_DIR := /srv/volumes/try-vmsingle/vmsingle/vmdata

.PHONY: up down ps logs prepare-dirs reset build generate

# Create (or verify) the host directory with permissions for UID/GID 1000.
# sudo may prompt for a password.
prepare-dirs:
	sudo install -d -o 1000 -g 1000 -m 0755 "$(VM_DATA_DIR)"

build:
	mkdir -p bin
	docker compose build go-builder
	docker compose run --rm --no-deps --user "$(id -u):$(id -g)" go-builder go build -o /out/sample-generator ./cmd/sample-generator

generate: build
	docker compose run --rm sample-generator

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
