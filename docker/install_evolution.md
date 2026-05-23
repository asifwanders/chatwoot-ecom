# Evolution-API WhatsApp Provider — Setup Guide

Evolution-API is a Baileys-based unofficial WhatsApp provider that runs as a
sidecar container in the same Docker Compose stack as Chatwoot-Ecom. It exposes
a REST API that the Rails backend calls to create WhatsApp instances, send QR
codes, and relay messages. Each WhatsApp number is registered as a separate
Evolution "instance", linked to a Chatwoot inbox. This setup assumes a
single-tenant, single-VPS deployment; for multi-customer reselling give each
customer their own VPS.

## Required environment variables

Add these to your `.env` (copy from `.env.example` as a starting point):

| Variable | Description |
|---|---|
| `EVOLUTION_API_URL` | Internal URL — always `http://evolution-api:8080` in Docker |
| `EVOLUTION_API_KEY` | Global API key shared between Rails and Evolution-API |
| `POSTGRES_PASSWORD` | Must be set; Evolution DB init uses it to create the `evolution` database |
| `REDIS_PASSWORD` | Must be set; Evolution uses Redis DB 1 for caching |

Generate a strong key:

```bash
openssl rand -hex 32
```

Paste the output as the value of `EVOLUTION_API_KEY` in `.env`.

## One-time setup

1. Copy the example file and fill in secrets:

   ```bash
   cp .env.example .env
   # edit .env — set POSTGRES_PASSWORD, REDIS_PASSWORD, EVOLUTION_API_KEY, etc.
   ```

2. Start the stack:

   ```bash
   docker compose -f docker-compose.fork.yaml up -d
   ```

   The `evolution-db-init` container runs once to create the `evolution`
   Postgres database, then exits. The `evolution-api` container starts after
   it completes.

3. Verify Evolution-API is reachable (run from the Rails container or the host
   if you temporarily publish port 8080):

   ```bash
   # from inside the rails container:
   curl -s -H "apikey: <YOUR_EVOLUTION_API_KEY>" \
     http://evolution-api:8080/manager/findInstances
   # expected: []
   ```

## Troubleshooting

Check Evolution-API logs:

```bash
docker compose -f docker-compose.fork.yaml logs -f evolution-api
```

Check the DB init logs if the service failed to start:

```bash
docker compose -f docker-compose.fork.yaml logs evolution-db-init
```

Reset all WhatsApp sessions (destroys QR login state — agents must re-scan):

```bash
docker compose -f docker-compose.fork.yaml stop evolution-api
docker volume rm chatwoot-ecom_evolution_instances
docker compose -f docker-compose.fork.yaml up -d evolution-api
```

Restart Evolution-API only (does not affect Chatwoot):

```bash
docker compose -f docker-compose.fork.yaml restart evolution-api
```
