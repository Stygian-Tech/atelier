BEGIN;

REVOKE ALL ON FUNCTION platform.current_tenant_id() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION platform.current_tenant_id()
    TO atelier_api, atelier_worker, atelier_mail_sync, atelier_calendar_sync, atelier_mcp;

REVOKE ALL ON FUNCTION jobs.enqueue(uuid, text, text, jsonb, timestamptz, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION jobs.lease_next(text, text[], interval) FROM PUBLIC;
REVOKE ALL ON FUNCTION jobs.complete(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION jobs.retry(uuid, text, timestamptz, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION jobs.dead_letter(uuid, text, text) FROM PUBLIC;

GRANT USAGE ON SCHEMA jobs TO atelier_api;
GRANT SELECT, INSERT ON jobs.queue, jobs.outbox TO atelier_api;
GRANT EXECUTE ON FUNCTION jobs.enqueue(uuid, text, text, jsonb, timestamptz, integer)
    TO atelier_api, atelier_mail_sync, atelier_calendar_sync, atelier_mcp;
GRANT EXECUTE ON FUNCTION jobs.lease_next(text, text[], interval),
    jobs.complete(uuid, text), jobs.retry(uuid, text, timestamptz, text), jobs.dead_letter(uuid, text, text)
    TO atelier_worker, atelier_mail_sync, atelier_calendar_sync;

COMMIT;
