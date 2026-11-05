VM_DATA_DIR := /srv/volumes/try-vmsingle/vmsingle/vmdata

.PHONY: up down ps logs prepare-dirs reset

# Create (or verify) the host directory with permissions for UID/GID 1000.
# sudo may prompt for a password.
prepare-dirs:
	sudo install -d -o 1000 -g 1000 -m 0755 "$(VM_DATA_DIR)"

up: prepare-dirs
	docker compose up -d

down:
	docker compose down

ps:
	docker compose ps

logs:
	docker compose logs -f vmsingle

# Stop and remove containers only. Bind-mounted host data is preserved.
reset:
	docker compose down -v
