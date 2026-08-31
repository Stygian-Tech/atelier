-- Administrative migration: execute as the database owner after 0001.
-- Runtime services receive membership in only one NOLOGIN role.
BEGIN;

DO $roles$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'atelier_api') THEN CREATE ROLE atelier_api NOLOGIN; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'atelier_worker') THEN CREATE ROLE atelier_worker NOLOGIN; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'atelier_mail_sync') THEN CREATE ROLE atelier_mail_sync NOLOGIN; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'atelier_calendar_sync') THEN CREATE ROLE atelier_calendar_sync NOLOGIN; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'atelier_mcp') THEN CREATE ROLE atelier_mcp NOLOGIN; END IF;
END
$roles$;

REVOKE ALL ON SCHEMA platform, notes, tasks, calendar, mail, collaboration, jobs, audit FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA platform, notes, tasks, calendar, mail, collaboration, jobs, audit FROM PUBLIC;

GRANT USAGE ON SCHEMA platform, notes, tasks, calendar, mail, collaboration, audit TO atelier_api;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA platform, notes, tasks, calendar, mail, collaboration TO atelier_api;
GRANT INSERT, SELECT ON audit.events TO atelier_api;

GRANT USAGE ON SCHEMA platform, jobs, audit TO atelier_worker;
GRANT SELECT ON platform.tenants TO atelier_worker;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA jobs TO atelier_worker;
GRANT INSERT, SELECT ON audit.events TO atelier_worker;

GRANT USAGE ON SCHEMA platform, mail, jobs, audit TO atelier_mail_sync;
GRANT SELECT ON platform.identities, platform.provider_credentials TO atelier_mail_sync;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA mail TO atelier_mail_sync;
GRANT SELECT, INSERT, UPDATE ON jobs.queue, jobs.outbox TO atelier_mail_sync;
GRANT INSERT, SELECT ON audit.events TO atelier_mail_sync;

GRANT USAGE ON SCHEMA platform, calendar, jobs, audit TO atelier_calendar_sync;
GRANT SELECT ON platform.identities, platform.provider_credentials TO atelier_calendar_sync;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA calendar TO atelier_calendar_sync;
GRANT SELECT, INSERT, UPDATE ON jobs.queue, jobs.outbox TO atelier_calendar_sync;
GRANT INSERT, SELECT ON audit.events TO atelier_calendar_sync;

GRANT USAGE ON SCHEMA platform, notes, tasks, calendar, mail, jobs, audit TO atelier_mcp;
GRANT SELECT ON ALL TABLES IN SCHEMA platform, notes, tasks, calendar, mail TO atelier_mcp;
GRANT INSERT ON jobs.queue, audit.events TO atelier_mcp;

COMMIT;
