# Atelier Railway infrastructure

`railway.ts` is the only Railway deployment configuration for this monorepo.
Railway's older per-service `railway.toml` / `railway.json` Config-as-Code
mechanism is deprecated and cannot be enabled for new services. Never set a
Railway Config File path for an Atelier service.

The authoring file intentionally contains only the eight deployable public
surfaces:

- marketing, docs, and status through their checked-in Dockerfiles;
- Home, Notes, Mail, Calendar, and Tasks through Railpack.

The API, worker, provider sync processes, Notes anchor, MCP backplane,
PostgreSQL, and Redis are intentionally absent until their readiness and
credential gates are complete.

## Environment behavior

- `development` follows `dev`, runs one `us-west2` replica per surface, enables
  app sleep, and caps each replica at 0.5 vCPU and 512 MiB.
- `production` follows `main`, defines the production domains, and runs one
  non-sleeping replica per surface only after its separately reviewed manual
  plan is applied. The checked-in replica count records the explicit 2026-08-30
  Production authorization; merging `main` alone does not apply infrastructure.
- Both environments fail closed if the linked Railway environment has any
  other name.

Limits are safety ceilings, not reservations. Railway bills actual CPU and
memory consumption. Review live metrics before raising them.

## Review and apply

Do not apply from an uncommitted `.railway` tree. First merge the required app
code and this file into the branch the target environment follows. Then link
the exact project and environment and create a pinned plan:

```sh
railway link --project "$ATELIER_RAILWAY_PROJECT_ID" --environment Development --json
railway status --json
railway config plan --file .railway/railway.ts --out /tmp/atelier-development-plan.json --verbose
railway config apply --plan /tmp/atelier-development-plan.json --yes
```

The apply command intentionally omits `--confirm-destructive`. An unexpected
delete must stop the rollout and receive a new review. Repeat the plan against
`Production` only after Development verification and the coordinated `main`
promotion.

The source declaration requires Railway's GitHub integration to have access to
`Stygian-Tech/atelier`. A public GitHub repository alone does not prove that the
authenticated Railway account can create repository deployment triggers.

## Domains and Marque

The IaC file reserves custom domains, but generated `*.up.railway.app` domains
are managed separately by Railway. After an individual service is healthy,
create and inspect its generated domain:

```sh
railway domain --project "$ATELIER_RAILWAY_PROJECT_ID" --environment Development --service marketing --json
railway domain status testing.atelier.diy --project "$ATELIER_RAILWAY_PROJECT_ID" --environment Development --service marketing --json
```

Repeat in this order: marketing, docs, status, home, notes, tasks, calendar,
then mail. Use the exact DNS target returned by Railway when preparing the
Marque transaction. Export and review the existing `atelier.diy` zone first;
do not infer targets or activate records from the hostnames in this file.
