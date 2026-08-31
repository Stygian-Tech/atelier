# Railway deployment contract

Atelier uses one Railway project with persistent Development and Production
environments. These files are source-controlled service templates; they do not
create a project, attach secrets, activate domains, or promote Production.

For each Railway service, set its config-as-code path to the absolute repository
path, for example `/infra/railway/services/notes-sync-anchor.toml`. Keep the
repository root as the build root because the Bun, Swift, and Rust workspaces
share packages. Watch paths prevent unrelated deployments.

## Services

The catalog contains Home, Notes, Mail, Calendar, Tasks, marketing, docs,
status, API, worker, Mail sync, Calendar sync, Notes sync anchor, MCP backplane,
Postgres, and Redis. Postgres and Redis should use Railway's managed templates;
they therefore have no source build config here.

Every source-backed service has a buildable path. Worker, Mail sync, Calendar
sync, API, MCP backplane, and the Notes sync anchor still fail readiness when
their required database adapters, authenticated executors, or live transport
loops are absent. Do not deploy a service merely because its container builds;
provision Development only after its documented readiness dependencies and
credential approval exist.

## Environment gates

- `dev` may deploy to Development after its referenced infrastructure exists.
- Production remains manual. `ATELIER_PRODUCTION_ACTIVATION_APPROVED=0` is not
  an application security control; it is a visible release guard.
- Provider credentials, KMS access, Sentry/Postmark tokens, and OAuth keys live
  only in Railway's secret store or workload identity. Never resolve the
  placeholders in the checked-in examples.
- `NEXT_PUBLIC_*` values are build-time inputs. Set all five product URLs on
  every product-web service so Development navigation never falls back to
  localhost or crosses into Production.
- Set the `ATELIER_*_ORIGIN` build-time values on marketing, docs, and status;
  their Development canonicals and cross-links must remain under the nested
  `*.testing.atelier.diy` hostnames.
- API, MCP, and Notes anchor rollout probes use `/readyz`. API and MCP derive
  readiness from their actual runtime dependencies; the Notes anchor remains
  unavailable while its checked-in `ATELIER_ANCHOR_READY` gate is `0`. Public
  web surfaces use `/` because they have no backing-service readiness dependency
  in this bootstrap.
- The API does not expose a migration command yet, so its Railway template does
  not pretend to run one. Add a guarded, lock-taking pre-deploy command only
  after the migration runner is implemented and verified locally.
