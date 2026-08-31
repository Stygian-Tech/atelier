# Atelier database foundation

`0001_foundation.sql` creates tenant-scoped domain schemas, encrypted-provider cache boundaries, the AppView indexes, durable jobs/outbox/dead letters, audit events, and forced row-level security. `0005_tenant_relational_isolation.sql` extends that boundary to `platform.tenants` and replaces cross-domain UUID references with tenant-qualified foreign keys.

Every request or worker transaction must run `SET LOCAL app.tenant_id = '<tenant UUID>'` before touching an RLS-protected table. A missing tenant setting deliberately sees no rows. The tenant table itself exposes only the row matching that setting, and runtime roles have no tenant mutation policy. Database owners and superusers can bypass RLS in operational contexts; runtime services must never connect as either.

Run `0002_scoped_roles.sql` separately as a role-admin account, then create one login per Railway service and grant it exactly one matching `NOLOGIN` role. Provider ciphertext is not useful without the separately controlled KMS key and encrypted DEK.

The `mail.provider_refs` table is an intentional privacy boundary and contains no provider content. Mail bodies expire no later than 30 days after caching; an unlink workflow must delete credentials and cached rows in the same durable operation.

## PostgreSQL 17 isolation verification

The disposable test applies every migration to a fresh PostgreSQL 17 container, switches to the real `atelier_api`, `atelier_calendar_sync`, `atelier_mail_sync`, and `atelier_worker` roles, and proves:

- tenant-scoped reads return only the active tenant;
- same-tenant identity, credential, account, cache, calendar, and job relationships succeed;
- cross-tenant relationships fail at the composite foreign key;
- the API role cannot insert, update, or delete tenant rows.

Run it with:

```sh
infra/database/tests/run-postgres17.sh
```
