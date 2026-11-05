.PHONY: up down ps logs reset

up:
	docker compose up -d

down:
	docker compose down

ps:
	docker compose ps

logs:
	docker compose logs -f vmsingle

# WARNING: removes the named volume and all local VictoriaMetrics data.
reset:
	docker compose down -v
