# Deployment

Atelier Mail deploys as two processes:

- `web`: Next.js app for `mail.atelierwork.space`.
- `api`: Swift API service on port `8080`.

PostgreSQL is the system of record. Private permissioned records stay in Atelier KV/Postgres until ATProto Permissioned Data is finalized.

## Required Environment

```bash
ATELIER_ENV=production
ATELIER_PUBLIC_URL=https://mail.atelierwork.space
ATELIER_API_URL=https://api.mail.atelierwork.space
NEXT_PUBLIC_ATELIER_API_URL=https://api.mail.atelierwork.space
ATELIER_DB_URL=postgres://...
ATELIER_KV_BACKEND=postgres
ATELIER_KMS_PROVIDER=...
ATELIER_TOKEN_KEK_ID=...
ATELIER_ATPROTO_CLIENT_ID=...
ATELIER_ATPROTO_REDIRECT_URI=https://mail.atelierwork.space/auth/callback
ATELIER_GMAIL_CLIENT_ID=...
ATELIER_GMAIL_CLIENT_SECRET=...
ATELIER_GMAIL_PUBSUB_AUDIENCE=...
ATELIER_MCP_ENABLED=true
ATELIER_MCP_MYCONTEXTPROTOCOL_URL=...
```

## Local Container Smoke

```bash
docker compose -f infra/docker-compose.yml up --build
curl http://localhost:8080/health
```

## API

The Swift API binary serves HTTP by default:

```bash
bun run start:api
```

For deployment metadata without starting the server:

```bash
bun run summary:api
```

## Verification

```bash
bun run verify:all
```

`verify:all` runs web typecheck/lint/tests/build and Swift API tests/build. The Swift Testing target expects the Xcode beta toolchain unless `DEVELOPER_DIR` is overridden.
