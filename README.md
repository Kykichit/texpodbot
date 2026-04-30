# Taskbot

Telegram is the primary
customer channel, while Chatwoot can be used as the operator desk.

The bot classifies support requests, runs deterministic diagnostics, persists
tickets/messages/events in PostgreSQL, and can hand off live conversations to
operators. Redis is used for runtime/cache/state dependencies. The project is
demo-ready after a local smoke test, pilot-ready with backups and monitoring,
and still needs production hardening before a full production launch.

## Quick Start

Local demo without live Telegram:

```bash
cp .env.demo.example .env.demo
docker compose --env-file .env.demo -f docker-compose.demo.yml up -d demo-postgres demo-redis
docker compose --env-file .env.demo -f docker-compose.demo.yml run --rm --build demo-app python -m app.main db-upgrade
docker compose --env-file .env.demo -f docker-compose.demo.yml up --build -d demo-app
```

Local demo with Telegram polling:

```bash
# Put a test bot token and test support group id into .env.demo first.
python scripts/chatwoot_local.py stop-taskbot-polling
docker compose --env-file .env.demo -f docker-compose.demo.yml run --rm demo-app python -m app.main run
```

Local self-host Chatwoot:

```bash
python scripts/chatwoot_local.py doctor
python scripts/chatwoot_local.py prepare
python scripts/chatwoot_local.py up
python scripts/chatwoot_local.py webhook-info
```

Do not commit `.env`, `.env.demo`, tokens, webhook secrets, database URLs, or
Chatwoot API tokens.

Configuration is loaded through `app.config.Settings`. Prefer structured
`DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `REDIS_HOST`, and `REDIS_DB`
values; `DATABASE_URL` and `REDIS_URL` remain supported for managed services.

## Main Commands

```bash
python -m app.main config-check --strict --json
python -m app.main db-upgrade
python -m app.main run
python -m app.main serve-webhook
python -m app.main runbooks validate
```

Demo helpers:

```bash
make demo-start
make demo-health
make demo-logs
make demo-stop
make compose-check
```

Chatwoot helpers:

```bash
python scripts/chatwoot_local.py doctor
python scripts/chatwoot_local.py webhook-info
python scripts/chatwoot_local.py stop-taskbot-polling
```

## CI/CD

GitHub Actions workflow lives in `.github/workflows/ci.yml` and runs on
`push`/`pull_request` to `main`. It installs Python 3.12 with pip cache, runs
`ruff`, `mypy src texpod_bot scripts`, and `pytest`, validates rendered Compose
configs, then builds the Docker image once with BuildKit.

Artifacts in Actions:

- `pytest-report`: JUnit test report from `pytest --junitxml`.
- `compose-configs`: rendered local and VPS Compose configs.
- `docker-build`: image digest/build metadata and build summary.

On pull requests the image is built locally for verification. On non-PR events
the verified image is pushed to GitHub Container Registry as
`ghcr.io/<owner>/<repo>:sha-<commit>` plus branch/tag aliases. Release or manual
deploy uses the immutable image digest from the `build-and-push` job, so the VPS
pulls the same artifact that passed CI.

Deployment is off by default for normal pushes. Enable it by publishing a GitHub
Release or by running the workflow manually with `deploy=true`. Required
repository secrets:

- `VPS_HOST`
- `VPS_USER`
- `VPS_SSH_KEY`
- `VPS_APP_DIR` optional, defaults to `/opt/taskbot`
- `GHCR_READ_TOKEN` with permission to pull the package from GHCR

Runtime values stay on the VPS in `.env.vps` and
`.env.chatwoot.production`. Change environment variables there or in GitHub
repository/environment secrets; never commit real tokens or passwords.

## Documentation

- [Quickstart](docs/quickstart.md)
- [Local Chatwoot setup](docs/chatwoot-local-setup.md)
- [All-in-one VPS with Chatwoot](docs/vps-all-in-one-chatwoot.md)
- [VPS deployment](docs/vps-deployment.md)
- [Operations](docs/operations.md)
- [Release checklist](docs/release-checklist.md)
- [Project status](docs/project-status.md)
- [Architecture](docs/architecture.md)
- [Operator runbook](docs/operator-runbook.md)
- [Metrics](docs/metrics.md)
- [UX copy style](docs/ux-copy-style.md)

## Production/VPS Overview

Recommended production shape:

- taskbot application container;
- PostgreSQL as the source of truth;
- Redis for runtime/cache/state;
- Caddy, Nginx, or Traefik for TLS and webhook routing;
- Chatwoot on the same VPS only if RAM allows, otherwise on a separate host;
- signed Chatwoot webhooks, `APP_ENV=production`, and
  `CHATWOOT_ALLOW_UNSIGNED_LOCAL_WEBHOOKS=false`.

For a compact single-server pilot, use
[All-in-one VPS with Chatwoot](docs/vps-all-in-one-chatwoot.md). It runs
taskbot, Chatwoot, Caddy HTTPS, PostgreSQL pgvector, and Redis on one VPS.
Copy `.env.vps.example` to `.env.vps`, copy
`.env.chatwoot.production.example` to `.env.chatwoot.production`, fill real
values on the server, then run:

```bash
sudo TASKBOT_DEPLOY_USER=<deploy-user> TASKBOT_APP_DIR=/opt/taskbot bash scripts/vps_bootstrap.sh
bash scripts/setup.sh doctor
bash scripts/setup.sh pull
bash scripts/setup.sh migrate
bash scripts/setup.sh up
```

The combined form is:

```bash
bash scripts/setup.sh deploy
```

Run migrations before starting a new version, check `/health` and `/ready`,
watch logs for delivery errors, and keep PostgreSQL backups with restore tests.
See [VPS deployment](docs/vps-deployment.md) and [Operations](docs/operations.md).

## Status

- Demo: ready after smoke test with `.env.demo`, migrations, `/ready`, one
  polling process, and a new test ticket.
- Pilot: possible when Telegram, Chatwoot, backups, basic monitoring, and an
  operator process are in place.
- Production: needs hardening around monitoring/alerting, backup automation,
  delivery retry/idempotency, SLA automation, secret management, and tested
  VPS/CI-CD deployment.
