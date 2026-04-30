DEMO_ENV ?= .env.demo
DEMO_ENV_EXAMPLE ?= .env.demo.example
DEMO_COMPOSE = docker compose --env-file $(DEMO_ENV) -f docker-compose.demo.yml
DEMO_COMPOSE_EXAMPLE = docker compose --env-file $(DEMO_ENV_EXAMPLE) -f docker-compose.demo.yml
VPS_ENV ?= .env.vps
VPS_COMPOSE = docker compose --env-file $(VPS_ENV) -f docker-compose.vps.yml

.PHONY: install run config-check db-upgrade db-shell chatwoot-smoke-docs lint format-check type-check test check docker-build compose-config compose-config-safe compose-check compose-up compose-down compose-logs compose-ps infra-up infra-down infra-logs infra-ps demo-copy-env demo-doctor demo-infra-up demo-migrate demo-run demo-start demo-stop demo-reset demo-seed demo-logs demo-ps demo-health vps-doctor vps-pull vps-migrate vps-up vps-setup vps-deploy vps-compose-config vps-build vps-ps vps-logs vps-health chatwoot-local-doctor chatwoot-local-ps chatwoot-local-prepare chatwoot-local-up chatwoot-local-stop chatwoot-local-logs chatwoot-local-open chatwoot-local-webhook-info chatwoot-local-reset chatwoot-local-stop-taskbot-polling

install:
	pip install -e ".[dev]"

run:
	python -m app.main run

config-check:
	python -m app.main config-check

db-upgrade:
	python -m app.main db-upgrade

db-shell:
	docker compose exec postgres psql -U support -d support

chatwoot-smoke-docs:
	@echo "See docs/chatwoot-smoke-test.md"

lint:
	python -m ruff check .

format-check:
	python -m ruff format --check .

type-check:
	python -m mypy src texpod_bot scripts

test:
	python -m pytest --junitxml=reports/pytest.xml

check:
	python -m ruff check .
	python -m ruff format --check .
	python -m mypy src texpod_bot scripts
	python -m pytest --junitxml=reports/pytest.xml

docker-build:
	docker build .

compose-config:
	docker compose config

compose-config-safe:
	docker compose --env-file .env.compose-check.example config

compose-check: compose-config-safe

compose-up:
	docker compose up --build

compose-down:
	docker compose down

compose-logs:
	docker compose logs -f app

compose-ps:
	docker compose ps

infra-up:
	docker compose up -d postgres redis

infra-down:
	docker compose down

infra-logs:
	docker compose logs -f postgres redis

infra-ps:
	docker compose ps

demo-copy-env:
	python -c "from pathlib import Path; src=Path('$(DEMO_ENV_EXAMPLE)'); dst=Path('$(DEMO_ENV)'); dst.exists() or dst.write_text(src.read_text(encoding='utf-8'), encoding='utf-8'); print(f'{dst} ready')"

demo-doctor:
	$(MAKE) demo-copy-env
	$(DEMO_COMPOSE_EXAMPLE) config
	$(DEMO_COMPOSE_EXAMPLE) run --rm --no-deps --build demo-app python -m app.main config-check --strict --json
	$(DEMO_COMPOSE_EXAMPLE) run --rm --no-deps --build demo-app python -m app.main runbooks validate

demo-infra-up:
	$(MAKE) demo-copy-env
	$(DEMO_COMPOSE) up -d demo-postgres demo-redis

demo-migrate:
	$(MAKE) demo-copy-env
	$(DEMO_COMPOSE) run --rm --build demo-app python -m app.main db-upgrade

demo-run:
	$(MAKE) demo-copy-env
	$(DEMO_COMPOSE) up --build demo-app

demo-start:
	$(MAKE) demo-copy-env
	$(DEMO_COMPOSE) up -d demo-postgres demo-redis
	$(MAKE) demo-migrate
	$(DEMO_COMPOSE) up --build -d demo-app

demo-stop:
	$(DEMO_COMPOSE) down

demo-reset:
	python -c "import os, sys; allowed=os.getenv('DEMO_ALLOW_RESET') == '1'; print('Set DEMO_ALLOW_RESET=1 to delete demo containers and volumes.') if not allowed else None; sys.exit(0 if allowed else 1)"
	$(DEMO_COMPOSE) down -v --remove-orphans

demo-seed:
	$(MAKE) demo-copy-env
	$(DEMO_COMPOSE) run --rm --no-deps --build demo-app python -m app.main runbooks validate
	@echo "No demo seed data is required yet; runbooks are validated."

demo-logs:
	$(DEMO_COMPOSE) logs -f demo-app demo-postgres demo-redis

demo-ps:
	$(DEMO_COMPOSE) ps

demo-health:
	python -c "import urllib.request; [print(f'{url}: {urllib.request.urlopen(url, timeout=3).status}') for url in ('http://127.0.0.1:18080/health', 'http://127.0.0.1:18080/ready')]"

vps-doctor:
	bash scripts/setup.sh doctor

vps-pull:
	bash scripts/setup.sh pull

vps-migrate:
	bash scripts/setup.sh migrate

vps-up:
	bash scripts/setup.sh up

vps-setup:
	bash scripts/setup.sh pull
	bash scripts/setup.sh migrate
	bash scripts/setup.sh up

vps-deploy:
	bash scripts/setup.sh deploy

vps-compose-config:
	$(VPS_COMPOSE) config

vps-build:
	$(VPS_COMPOSE) build app

vps-ps:
	$(VPS_COMPOSE) ps

vps-logs:
	$(VPS_COMPOSE) logs -f app chatwoot-rails chatwoot-worker caddy

vps-health:
	curl -fsS $${BOT_PUBLIC_URL:-https://<bot-domain>}/health

chatwoot-local-doctor:
	python scripts/chatwoot_local.py doctor

chatwoot-local-ps:
	python scripts/chatwoot_local.py ps

chatwoot-local-prepare:
	python scripts/chatwoot_local.py prepare

chatwoot-local-up:
	python scripts/chatwoot_local.py up

chatwoot-local-stop:
	python scripts/chatwoot_local.py stop

chatwoot-local-logs:
	python scripts/chatwoot_local.py logs

chatwoot-local-open:
	python scripts/chatwoot_local.py open

chatwoot-local-webhook-info:
	python scripts/chatwoot_local.py webhook-info

chatwoot-local-reset:
	python scripts/chatwoot_local.py reset

chatwoot-local-stop-taskbot-polling:
	python scripts/chatwoot_local.py stop-taskbot-polling
