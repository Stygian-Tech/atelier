BEGIN;

-- Tenant rows are visible only to the runtime transaction's tenant. Runtime
-- roles intentionally receive no tenant mutation policy, even if a later grant
-- accidentally restores a table-level write privilege.
ALTER TABLE platform.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform.tenants FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_scoped_read ON platform.tenants
    FOR SELECT
    USING (id = platform.current_tenant_id());

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
    ON platform.tenants
    FROM atelier_api, atelier_worker, atelier_mail_sync, atelier_calendar_sync, atelier_mcp;

-- Preserve the tenant reads granted by the earlier role migration while making
-- the API grant explicit after the broad platform-table grant is narrowed.
GRANT SELECT ON platform.tenants TO atelier_api, atelier_worker, atelier_mcp;

-- Composite parent keys let every relationship carry the tenant identity into
-- referential integrity instead of trusting an independently supplied UUID.
ALTER TABLE platform.identities
    ADD CONSTRAINT identities_tenant_id_id_key UNIQUE (tenant_id, id);
ALTER TABLE platform.provider_credentials
    ADD CONSTRAINT provider_credentials_tenant_id_id_key UNIQUE (tenant_id, id);
ALTER TABLE mail.accounts
    ADD CONSTRAINT accounts_tenant_id_id_key UNIQUE (tenant_id, id);
ALTER TABLE jobs.queue
    ADD CONSTRAINT queue_tenant_id_id_key UNIQUE (tenant_id, id);

ALTER TABLE platform.sessions
    ADD CONSTRAINT sessions_tenant_identity_fkey
    FOREIGN KEY (tenant_id, identity_id)
    REFERENCES platform.identities (tenant_id, id)
    ON DELETE CASCADE
    NOT VALID;

ALTER TABLE platform.provider_credentials
    ADD CONSTRAINT provider_credentials_tenant_identity_fkey
    FOREIGN KEY (tenant_id, identity_id)
    REFERENCES platform.identities (tenant_id, id)
    ON DELETE CASCADE
    NOT VALID;

ALTER TABLE calendar.provider_events
    ADD CONSTRAINT provider_events_tenant_account_fkey
    FOREIGN KEY (tenant_id, account_id)
    REFERENCES platform.provider_credentials (tenant_id, id)
    ON DELETE CASCADE
    NOT VALID;

ALTER TABLE mail.accounts
    ADD CONSTRAINT accounts_tenant_credential_fkey
    FOREIGN KEY (tenant_id, credential_id)
    REFERENCES platform.provider_credentials (tenant_id, id)
    ON DELETE CASCADE
    NOT VALID;

ALTER TABLE mail.cached_headers
    ADD CONSTRAINT cached_headers_tenant_account_fkey
    FOREIGN KEY (tenant_id, account_id)
    REFERENCES mail.accounts (tenant_id, id)
    ON DELETE CASCADE
    NOT VALID;

ALTER TABLE mail.cached_bodies
    ADD CONSTRAINT cached_bodies_tenant_account_fkey
    FOREIGN KEY (tenant_id, account_id)
    REFERENCES mail.accounts (tenant_id, id)
    ON DELETE CASCADE
    NOT VALID;

ALTER TABLE jobs.dead_letters
    ADD CONSTRAINT dead_letters_tenant_original_job_fkey
    FOREIGN KEY (tenant_id, original_job_id)
    REFERENCES jobs.queue (tenant_id, id)
    ON DELETE CASCADE
    NOT VALID;

-- Validate before removing the legacy single-column relationships so an
-- existing tenant mismatch aborts the migration without weakening integrity.
ALTER TABLE platform.sessions VALIDATE CONSTRAINT sessions_tenant_identity_fkey;
ALTER TABLE platform.provider_credentials VALIDATE CONSTRAINT provider_credentials_tenant_identity_fkey;
ALTER TABLE calendar.provider_events VALIDATE CONSTRAINT provider_events_tenant_account_fkey;
ALTER TABLE mail.accounts VALIDATE CONSTRAINT accounts_tenant_credential_fkey;
ALTER TABLE mail.cached_headers VALIDATE CONSTRAINT cached_headers_tenant_account_fkey;
ALTER TABLE mail.cached_bodies VALIDATE CONSTRAINT cached_bodies_tenant_account_fkey;
ALTER TABLE jobs.dead_letters VALIDATE CONSTRAINT dead_letters_tenant_original_job_fkey;

ALTER TABLE platform.sessions DROP CONSTRAINT sessions_identity_id_fkey;
ALTER TABLE platform.provider_credentials DROP CONSTRAINT provider_credentials_identity_id_fkey;
ALTER TABLE calendar.provider_events DROP CONSTRAINT provider_events_account_id_fkey;
ALTER TABLE mail.accounts DROP CONSTRAINT accounts_credential_id_fkey;
ALTER TABLE mail.cached_headers DROP CONSTRAINT cached_headers_account_id_fkey;
ALTER TABLE mail.cached_bodies DROP CONSTRAINT cached_bodies_account_id_fkey;

-- PostgreSQL does not create indexes for referencing columns. Existing primary
-- and unique keys cover every new child relationship except these two.
CREATE INDEX sessions_tenant_identity_idx
    ON platform.sessions (tenant_id, identity_id);
CREATE INDEX mail_accounts_tenant_credential_idx
    ON mail.accounts (tenant_id, credential_id);

COMMIT;
