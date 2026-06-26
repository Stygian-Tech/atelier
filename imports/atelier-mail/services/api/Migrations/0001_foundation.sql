CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE tenants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  did TEXT NOT NULL,
  handle TEXT NOT NULL,
  pds_endpoint TEXT NOT NULL,
  did_document JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, did)
);

CREATE TABLE sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  session_hash TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE permissioned_kv_records (
  owner_did TEXT NOT NULL,
  namespace TEXT NOT NULL,
  record_key TEXT NOT NULL,
  schema_version INTEGER NOT NULL,
  encrypted_payload BYTEA NOT NULL,
  encryption_key_ref TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (owner_did, namespace, record_key),
  CONSTRAINT permissioned_namespace_check CHECK (namespace LIKE 'space.atelierwork.%')
);

CREATE TABLE provider_secrets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider TEXT NOT NULL,
  encrypted_refresh_token BYTEA,
  encrypted_access_token BYTEA,
  encrypted_dek BYTEA NOT NULL,
  kms_key_id TEXT NOT NULL,
  kms_key_version TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE mail_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider TEXT NOT NULL CHECK (provider IN ('gmail', 'jmap', 'imap')),
  display_name TEXT NOT NULL,
  provider_descriptor_key TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE mailboxes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID NOT NULL REFERENCES mail_accounts(id) ON DELETE CASCADE,
  provider_id TEXT NOT NULL,
  name TEXT NOT NULL,
  role TEXT NOT NULL,
  UNIQUE (account_id, provider_id)
);

CREATE TABLE mail_threads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID NOT NULL REFERENCES mail_accounts(id) ON DELETE CASCADE,
  provider_thread_id TEXT NOT NULL,
  subject TEXT NOT NULL,
  participants_summary TEXT NOT NULL,
  snippet TEXT NOT NULL,
  unread_count INTEGER NOT NULL DEFAULT 0,
  last_message_at TIMESTAMPTZ NOT NULL,
  search_vector TSVECTOR,
  UNIQUE (account_id, provider_thread_id)
);

CREATE INDEX mail_threads_search_idx ON mail_threads USING GIN (search_vector);
CREATE INDEX mail_threads_account_last_message_idx ON mail_threads (account_id, last_message_at DESC);

CREATE TABLE mail_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id UUID NOT NULL REFERENCES mail_threads(id) ON DELETE CASCADE,
  provider_message_id TEXT NOT NULL,
  message_id_header TEXT NOT NULL,
  sender JSONB NOT NULL,
  recipients JSONB NOT NULL,
  sent_at TIMESTAMPTZ NOT NULL,
  text_body TEXT,
  html_body TEXT,
  UNIQUE (thread_id, provider_message_id)
);

CREATE TABLE sync_cursors (
  account_id UUID PRIMARY KEY REFERENCES mail_accounts(id) ON DELETE CASCADE,
  provider_cursor TEXT,
  last_synced_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID REFERENCES mail_accounts(id) ON DELETE CASCADE,
  kind TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}',
  attempts INTEGER NOT NULL DEFAULT 0,
  not_before TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE audit_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  event_type TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
