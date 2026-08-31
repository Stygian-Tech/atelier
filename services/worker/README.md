# Atelier durable worker

The worker owns generic durable-job execution, outbox publication, retry/backoff, and dead-letter transitions. It leases work through the `jobs.lease_next` database function using `FOR UPDATE SKIP LOCKED`; Redis may wake workers but is never the source of truth.

Initial job families are `pds.index`, `pds.write`, `search.reindex`, `notification.deliver`, `provider.purge`, and `audit.expire`. Every producer supplies a tenant-scoped idempotency key.

The Swift package now provides the executable, configuration validation, a structured single-lease processor, bounded exponential retry, stable error codes, dead-letter transitions, and injectable durable-store/handler seams. The executable deliberately refuses readiness because the Postgres `DurableJobStore` adapter and domain handlers are not implemented. `DATABASE_URL` and `ATELIER_ENV` are required and unresolved Railway placeholders are rejected; adding credentials alone does not enable processing.
