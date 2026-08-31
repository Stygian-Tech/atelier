BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS platform;
CREATE SCHEMA IF NOT EXISTS notes;
CREATE SCHEMA IF NOT EXISTS tasks;
CREATE SCHEMA IF NOT EXISTS calendar;
CREATE SCHEMA IF NOT EXISTS mail;
CREATE SCHEMA IF NOT EXISTS collaboration;
CREATE SCHEMA IF NOT EXISTS jobs;
CREATE SCHEMA IF NOT EXISTS audit;

CREATE TABLE platform.tenants (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    slug text NOT NULL UNIQUE,
    created_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE platform.identities (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL REFERENCES platform.tenants(id) ON DELETE CASCADE,
    did text NOT NULL CHECK (did LIKE 'did:%'),
    handle text,
    pds_endpoint text NOT NULL,
    did_document jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, did)
);

CREATE TABLE platform.sessions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL REFERENCES platform.tenants(id) ON DELETE CASCADE,
    identity_id uuid NOT NULL REFERENCES platform.identities(id) ON DELETE CASCADE,
    session_hash bytea NOT NULL UNIQUE,
    granted_scopes text[] NOT NULL DEFAULT '{}',
    expires_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE platform.provider_credentials (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL REFERENCES platform.tenants(id) ON DELETE CASCADE,
    identity_id uuid NOT NULL REFERENCES platform.identities(id) ON DELETE CASCADE,
    provider text NOT NULL CHECK (provider IN ('gmail', 'jmap', 'imap', 'google_calendar', 'microsoft_calendar', 'caldav')),
    encrypted_credentials bytea NOT NULL,
    encrypted_dek bytea NOT NULL,
    kms_key_resource text NOT NULL,
    scopes text[] NOT NULL DEFAULT '{}',
    revoked_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, identity_id, provider, id)
);

CREATE TABLE platform.record_index (
    tenant_id uuid NOT NULL REFERENCES platform.tenants(id) ON DELETE CASCADE,
    owner_did text NOT NULL CHECK (owner_did LIKE 'did:%'),
    uri text NOT NULL CHECK (uri LIKE 'at://%'),
    cid text NOT NULL,
    collection text NOT NULL CHECK (collection LIKE 'diy.atelier.%' OR collection LIKE 'community.lexicon.calendar.%'),
    rkey text NOT NULL,
    indexed_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    PRIMARY KEY (tenant_id, uri)
);

CREATE TABLE platform.relationship_index (
    tenant_id uuid NOT NULL REFERENCES platform.tenants(id) ON DELETE CASCADE,
    edge_uri text NOT NULL CHECK (edge_uri LIKE 'at://%'),
    actor_did text NOT NULL CHECK (actor_did LIKE 'did:%'),
    source_uri text NOT NULL,
    target_uri text NOT NULL,
    kind text NOT NULL,
    indexed_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, edge_uri)
);
CREATE INDEX relationship_backlink_idx ON platform.relationship_index (tenant_id, target_uri, kind);

CREATE TABLE notes.document_index (
    tenant_id uuid NOT NULL REFERENCES platform.tenants(id) ON DELETE CASCADE,
    uri text NOT NULL CHECK (uri LIKE 'at://%'),
    owner_did text NOT NULL CHECK (owner_did LIKE 'did:%'),
    title text NOT NULL,
    materialized_markdown text NOT NULL,
    tags text[] NOT NULL DEFAULT '{}',
    project_uri text,
    search_vector tsvector GENERATED ALWAYS AS (to_tsvector('simple', title || ' ' || materialized_markdown)) STORED,
    source_cid text NOT NULL,
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (tenant_id, uri)
);
CREATE INDEX notes_search_idx ON notes.document_index USING gin (search_vector);

CREATE TABLE tasks.task_index (
    tenant_id uuid NOT NULL REFERENCES platform.tenants(id) ON DELETE CASCADE,
    uri text NOT NULL CHECK (uri LIKE 'at://%'),
    owner_did text NOT NULL CHECK (owner_did LIKE 'did:%'),
    title text NOT NULL,
    status text NOT NULL CHECK (status IN ('todo', 'inProgress', 'completed', 'cancelled')),
    project_uri text,
    due_at timestamptz,
    source_cid text NOT NULL,
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (tenant_id, uri)
);
CREATE INDEX tasks_due_idx ON tasks.task_index (tenant_id, status, due_at) WHERE due_at IS NOT NULL;

CREATE TABLE calendar.event_index (
    tenant_id uuid NOT NULL REFERENCES platform.tenants(id) ON DELETE CASCADE,
    uri text NOT NULL CHECK (uri LIKE 'at://%'),
    owner_did text NOT NULL CHECK (owner_did LIKE 'did:%'),
    ical_uid text NOT NULL,
    title text NOT NULL,
    starts_at timestamptz,
    ends_at timestamptz,
    source_cid text NOT NULL,
    community_event_uri text,
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (tenant_id, uri),
    UNIQUE (tenant_id, owner_did, ical_uid)
);

CREATE TABLE calendar.provider_events (
    tenant_id uuid NOT NULL REFERENCES platform.tenants(id) ON DELETE CASCADE,
    account_id uuid NOT NULL REFERENCES platform.provider_credentials(id) ON DELETE CASCADE,
    opaque_id bytea NOT NULL,
    source_version text NOT NULL,
    encrypted_event bytea NOT NULL,
    encrypted_dek bytea NOT NULL,
    kms_key_resource text NOT NULL,
    sync_token text,
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, account_id, opaque_id)
);

CREATE TABLE mail.accounts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL REFERENCES platform.tenants(id) ON DELETE CASCADE,
    credential_id uuid NOT NULL REFERENCES platform.provider_credentials(id) ON DELETE CASCADE,
    provider text NOT NULL CHECK (provider IN ('gmail', 'jmap', 'imap')),
    provider_account_key bytea NOT NULL,
    display_name text NOT NULL,
    sync_cursor text,
    watch_expires_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, provider, provider_account_key)
);

CREATE TABLE mail.provider_refs (
    tenant_id uuid NOT NULL REFERENCES platform.tenants(id) ON DELETE CASCADE,
    owner_did text NOT NULL CHECK (owner_did LIKE 'did:%'),
    record_uri text NOT NULL CHECK (record_uri LIKE 'at://%'),
    provider text NOT NULL CHECK (provider IN ('gmail', 'jmap', 'imap')),
    opaque_id bytea NOT NULL,
    resource_kind text NOT NULL CHECK (resource_kind IN ('account', 'mailbox', 'thread', 'message', 'draft')),
    source_version text NOT NULL,
    indexed_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, record_uri),
    UNIQUE (tenant_id, provider, resource_kind, opaque_id)
);
COMMENT ON TABLE mail.provider_refs IS 'Privacy boundary: HMAC-derived identifiers and source metadata only; never subject, participants, snippet, headers, or body.';

CREATE TABLE mail.cached_headers (
    tenant_id uuid NOT NULL REFERENCES platform.tenants(id) ON DELETE CASCADE,
    account_id uuid NOT NULL REFERENCES mail.accounts(id) ON DELETE CASCADE,
    opaque_message_id bytea NOT NULL,
    encrypted_headers bytea NOT NULL,
    encrypted_dek bytea NOT NULL,
    kms_key_resource text NOT NULL,
    source_version text NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, account_id, opaque_message_id)
);

CREATE TABLE mail.cached_bodies (
    tenant_id uuid NOT NULL REFERENCES platform.tenants(id) ON DELETE CASCADE,
    account_id uuid NOT NULL REFERENCES mail.accounts(id) ON DELETE CASCADE,
    opaque_message_id bytea NOT NULL,
    encrypted_body bytea NOT NULL,
    encrypted_dek bytea NOT NULL,
    kms_key_resource text NOT NULL,
    cached_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz NOT NULL DEFAULT (now() + interval '30 days'),
    PRIMARY KEY (tenant_id, account_id, opaque_message_id),
    CHECK (expires_at <= cached_at + interval '30 days')
);
CREATE INDEX mail_cached_body_expiry_idx ON mail.cached_bodies (expires_at);

CREATE TABLE collaboration.checkpoints (
    tenant_id uuid NOT NULL REFERENCES platform.tenants(id) ON DELETE CASCADE,
    document_uri text NOT NULL CHECK (document_uri LIKE 'at://%'),
    checkpoint_uri text NOT NULL CHECK (checkpoint_uri LIKE 'at://%'),
    content_hash text NOT NULL,
    heads text[] NOT NULL,
    protocol_version integer NOT NULL CHECK (protocol_version > 0),
    persistence_state text NOT NULL CHECK (persistence_state IN ('local', 'converged', 'durable')),
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (tenant_id, document_uri)
);

CREATE TABLE jobs.queue (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL REFERENCES platform.tenants(id) ON DELETE CASCADE,
    kind text NOT NULL,
    idempotency_key text NOT NULL,
    payload jsonb NOT NULL DEFAULT '{}',
    state text NOT NULL DEFAULT 'pending' CHECK (state IN ('pending', 'leased', 'succeeded', 'dead')),
    attempts integer NOT NULL DEFAULT 0 CHECK (attempts >= 0),
    max_attempts integer NOT NULL DEFAULT 10 CHECK (max_attempts > 0),
    not_before timestamptz NOT NULL DEFAULT now(),
    lease_owner text,
    lease_expires_at timestamptz,
    last_error_code text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, kind, idempotency_key),
    CHECK ((state = 'leased') = (lease_owner IS NOT NULL AND lease_expires_at IS NOT NULL))
);
CREATE INDEX jobs_lease_idx ON jobs.queue (kind, not_before, created_at) WHERE state = 'pending';

CREATE TABLE jobs.outbox (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL REFERENCES platform.tenants(id) ON DELETE CASCADE,
    topic text NOT NULL,
    aggregate_key text NOT NULL,
    idempotency_key text NOT NULL,
    payload jsonb NOT NULL,
    published_at timestamptz,
    attempts integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, topic, idempotency_key)
);
CREATE INDEX outbox_pending_idx ON jobs.outbox (created_at) WHERE published_at IS NULL;

CREATE TABLE jobs.dead_letters (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL REFERENCES platform.tenants(id) ON DELETE CASCADE,
    original_job_id uuid NOT NULL,
    kind text NOT NULL,
    payload jsonb NOT NULL,
    error_code text NOT NULL,
    attempts integer NOT NULL,
    failed_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, original_job_id)
);

CREATE TABLE audit.events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL REFERENCES platform.tenants(id) ON DELETE CASCADE,
    actor_did text CHECK (actor_did IS NULL OR actor_did LIKE 'did:%'),
    event_type text NOT NULL,
    resource_uri text,
    request_id text,
    metadata jsonb NOT NULL DEFAULT '{}',
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX audit_tenant_time_idx ON audit.events (tenant_id, created_at DESC);

CREATE FUNCTION platform.current_tenant_id() RETURNS uuid
LANGUAGE sql STABLE AS $$
    SELECT nullif(current_setting('app.tenant_id', true), '')::uuid
$$;

DO $rls$
DECLARE
    target regclass;
BEGIN
    FOREACH target IN ARRAY ARRAY[
        'platform.identities'::regclass, 'platform.sessions'::regclass,
        'platform.provider_credentials'::regclass, 'platform.record_index'::regclass,
        'platform.relationship_index'::regclass, 'notes.document_index'::regclass,
        'tasks.task_index'::regclass, 'calendar.event_index'::regclass,
        'calendar.provider_events'::regclass, 'mail.accounts'::regclass,
        'mail.provider_refs'::regclass, 'mail.cached_headers'::regclass,
        'mail.cached_bodies'::regclass, 'collaboration.checkpoints'::regclass,
        'jobs.queue'::regclass, 'jobs.outbox'::regclass, 'jobs.dead_letters'::regclass,
        'audit.events'::regclass
    ] LOOP
        EXECUTE format('ALTER TABLE %s ENABLE ROW LEVEL SECURITY', target);
        EXECUTE format('ALTER TABLE %s FORCE ROW LEVEL SECURITY', target);
        EXECUTE format(
            'CREATE POLICY tenant_isolation ON %s USING (tenant_id = platform.current_tenant_id()) WITH CHECK (tenant_id = platform.current_tenant_id())',
            target
        );
    END LOOP;
END
$rls$;

COMMIT;
