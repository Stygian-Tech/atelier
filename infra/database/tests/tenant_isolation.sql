\set ON_ERROR_STOP on

-- Stable fixture identities make failures reproducible and easy to diagnose.
INSERT INTO platform.tenants (id, slug) VALUES
    ('11111111-1111-4111-8111-111111111111', 'tenant-a'),
    ('22222222-2222-4222-8222-222222222222', 'tenant-b');

INSERT INTO platform.identities (id, tenant_id, did, pds_endpoint) VALUES
    ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '11111111-1111-4111-8111-111111111111', 'did:plc:tenant-a', 'https://pds-a.example'),
    ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '22222222-2222-4222-8222-222222222222', 'did:plc:tenant-b', 'https://pds-b.example');

INSERT INTO platform.provider_credentials (
    id, tenant_id, identity_id, provider, encrypted_credentials, encrypted_dek, kms_key_resource
) VALUES
    (
        'aaaaaaaa-0000-4000-8000-000000000001',
        '11111111-1111-4111-8111-111111111111',
        'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        'gmail', decode('01', 'hex'), decode('02', 'hex'), 'kms://tenant-a'
    ),
    (
        'bbbbbbbb-0000-4000-8000-000000000001',
        '22222222-2222-4222-8222-222222222222',
        'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        'gmail', decode('03', 'hex'), decode('04', 'hex'), 'kms://tenant-b'
    );

INSERT INTO mail.accounts (
    id, tenant_id, credential_id, provider, provider_account_key, display_name
) VALUES (
    'bbbbbbbb-0000-4000-8000-000000000002',
    '22222222-2222-4222-8222-222222222222',
    'bbbbbbbb-0000-4000-8000-000000000001',
    'gmail', decode('05', 'hex'), 'Tenant B Mail'
);

INSERT INTO jobs.queue (id, tenant_id, kind, idempotency_key) VALUES
    ('aaaaaaaa-0000-4000-8000-000000000003', '11111111-1111-4111-8111-111111111111', 'test', 'tenant-a-job'),
    ('bbbbbbbb-0000-4000-8000-000000000003', '22222222-2222-4222-8222-222222222222', 'test', 'tenant-b-job');

DO $assert_schema$
DECLARE
    constraint_name text;
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_class
        WHERE oid = 'platform.tenants'::regclass
          AND relrowsecurity
          AND relforcerowsecurity
    ) THEN
        RAISE EXCEPTION 'platform.tenants must enable and force RLS';
    END IF;

    FOREACH constraint_name IN ARRAY ARRAY[
        'sessions_tenant_identity_fkey',
        'provider_credentials_tenant_identity_fkey',
        'provider_events_tenant_account_fkey',
        'accounts_tenant_credential_fkey',
        'cached_headers_tenant_account_fkey',
        'cached_bodies_tenant_account_fkey',
        'dead_letters_tenant_original_job_fkey'
    ] LOOP
        IF NOT EXISTS (
            SELECT 1
            FROM pg_constraint
            WHERE conname = constraint_name
              AND contype = 'f'
              AND confdeltype = 'c'
              AND convalidated
        ) THEN
            RAISE EXCEPTION 'missing validated cascading constraint %', constraint_name;
        END IF;
    END LOOP;
END
$assert_schema$;

SET ROLE atelier_api;
SELECT set_config('app.tenant_id', '11111111-1111-4111-8111-111111111111', false);

DO $api_visibility$
BEGIN
    IF (SELECT count(*) FROM platform.tenants) <> 1 OR
       (SELECT slug FROM platform.tenants) <> 'tenant-a' THEN
        RAISE EXCEPTION 'atelier_api crossed the tenant row boundary';
    END IF;
    IF (SELECT count(*) FROM platform.identities) <> 1 OR
       (SELECT did FROM platform.identities) <> 'did:plc:tenant-a' THEN
        RAISE EXCEPTION 'atelier_api crossed the identity row boundary';
    END IF;
END
$api_visibility$;

INSERT INTO platform.sessions (
    id, tenant_id, identity_id, session_hash, expires_at
) VALUES (
    'aaaaaaaa-0000-4000-8000-000000000010',
    '11111111-1111-4111-8111-111111111111',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    decode('10', 'hex'), now() + interval '1 hour'
);

INSERT INTO platform.provider_credentials (
    id, tenant_id, identity_id, provider, encrypted_credentials, encrypted_dek, kms_key_resource
) VALUES (
    'aaaaaaaa-0000-4000-8000-000000000011',
    '11111111-1111-4111-8111-111111111111',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'imap', decode('11', 'hex'), decode('12', 'hex'), 'kms://tenant-a'
);

DO $api_cross_tenant_relations$
BEGIN
    BEGIN
        INSERT INTO platform.sessions (
            id, tenant_id, identity_id, session_hash, expires_at
        ) VALUES (
            'aaaaaaaa-0000-4000-8000-000000000012',
            '11111111-1111-4111-8111-111111111111',
            'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
            decode('13', 'hex'), now() + interval '1 hour'
        );
        RAISE EXCEPTION 'cross-tenant session relation unexpectedly succeeded';
    EXCEPTION WHEN foreign_key_violation THEN
        NULL;
    END;

    BEGIN
        INSERT INTO platform.provider_credentials (
            id, tenant_id, identity_id, provider, encrypted_credentials, encrypted_dek, kms_key_resource
        ) VALUES (
            'aaaaaaaa-0000-4000-8000-000000000013',
            '11111111-1111-4111-8111-111111111111',
            'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
            'jmap', decode('14', 'hex'), decode('15', 'hex'), 'kms://tenant-a'
        );
        RAISE EXCEPTION 'cross-tenant credential relation unexpectedly succeeded';
    EXCEPTION WHEN foreign_key_violation THEN
        NULL;
    END;
END
$api_cross_tenant_relations$;

DO $api_tenant_mutation$
BEGIN
    BEGIN
        INSERT INTO platform.tenants (slug) VALUES ('api-created');
        RAISE EXCEPTION 'atelier_api unexpectedly inserted a tenant';
    EXCEPTION WHEN insufficient_privilege THEN
        NULL;
    END;

    BEGIN
        UPDATE platform.tenants SET slug = 'api-updated'
        WHERE id = '11111111-1111-4111-8111-111111111111';
        RAISE EXCEPTION 'atelier_api unexpectedly updated a tenant';
    EXCEPTION WHEN insufficient_privilege THEN
        NULL;
    END;

    BEGIN
        DELETE FROM platform.tenants
        WHERE id = '11111111-1111-4111-8111-111111111111';
        RAISE EXCEPTION 'atelier_api unexpectedly deleted a tenant';
    EXCEPTION WHEN insufficient_privilege THEN
        NULL;
    END;
END
$api_tenant_mutation$;

RESET ROLE;
RESET app.tenant_id;

SET ROLE atelier_calendar_sync;
SELECT set_config('app.tenant_id', '11111111-1111-4111-8111-111111111111', false);

INSERT INTO calendar.provider_events (
    tenant_id, account_id, opaque_id, source_version,
    encrypted_event, encrypted_dek, kms_key_resource
) VALUES (
    '11111111-1111-4111-8111-111111111111',
    'aaaaaaaa-0000-4000-8000-000000000001',
    decode('20', 'hex'), 'v1', decode('21', 'hex'), decode('22', 'hex'), 'kms://tenant-a'
);

DO $calendar_cross_tenant_relation$
BEGIN
    BEGIN
        INSERT INTO calendar.provider_events (
            tenant_id, account_id, opaque_id, source_version,
            encrypted_event, encrypted_dek, kms_key_resource
        ) VALUES (
            '11111111-1111-4111-8111-111111111111',
            'bbbbbbbb-0000-4000-8000-000000000001',
            decode('23', 'hex'), 'v1', decode('24', 'hex'), decode('25', 'hex'), 'kms://tenant-a'
        );
        RAISE EXCEPTION 'cross-tenant calendar credential relation unexpectedly succeeded';
    EXCEPTION WHEN foreign_key_violation THEN
        NULL;
    END;
END
$calendar_cross_tenant_relation$;

RESET ROLE;
RESET app.tenant_id;

SET ROLE atelier_mail_sync;
SELECT set_config('app.tenant_id', '11111111-1111-4111-8111-111111111111', false);

INSERT INTO mail.accounts (
    id, tenant_id, credential_id, provider, provider_account_key, display_name
) VALUES (
    'aaaaaaaa-0000-4000-8000-000000000002',
    '11111111-1111-4111-8111-111111111111',
    'aaaaaaaa-0000-4000-8000-000000000001',
    'gmail', decode('30', 'hex'), 'Tenant A Mail'
);

INSERT INTO mail.cached_headers (
    tenant_id, account_id, opaque_message_id,
    encrypted_headers, encrypted_dek, kms_key_resource, source_version
) VALUES (
    '11111111-1111-4111-8111-111111111111',
    'aaaaaaaa-0000-4000-8000-000000000002',
    decode('31', 'hex'), decode('32', 'hex'), decode('33', 'hex'), 'kms://tenant-a', 'v1'
);

INSERT INTO mail.cached_bodies (
    tenant_id, account_id, opaque_message_id,
    encrypted_body, encrypted_dek, kms_key_resource
) VALUES (
    '11111111-1111-4111-8111-111111111111',
    'aaaaaaaa-0000-4000-8000-000000000002',
    decode('34', 'hex'), decode('35', 'hex'), decode('36', 'hex'), 'kms://tenant-a'
);

DO $mail_cross_tenant_relations$
BEGIN
    BEGIN
        INSERT INTO mail.accounts (
            id, tenant_id, credential_id, provider, provider_account_key, display_name
        ) VALUES (
            'aaaaaaaa-0000-4000-8000-000000000003',
            '11111111-1111-4111-8111-111111111111',
            'bbbbbbbb-0000-4000-8000-000000000001',
            'gmail', decode('37', 'hex'), 'Cross-tenant Mail'
        );
        RAISE EXCEPTION 'cross-tenant mail credential relation unexpectedly succeeded';
    EXCEPTION WHEN foreign_key_violation THEN
        NULL;
    END;

    BEGIN
        INSERT INTO mail.cached_headers (
            tenant_id, account_id, opaque_message_id,
            encrypted_headers, encrypted_dek, kms_key_resource, source_version
        ) VALUES (
            '11111111-1111-4111-8111-111111111111',
            'bbbbbbbb-0000-4000-8000-000000000002',
            decode('38', 'hex'), decode('39', 'hex'), decode('3a', 'hex'), 'kms://tenant-a', 'v1'
        );
        RAISE EXCEPTION 'cross-tenant cached-header relation unexpectedly succeeded';
    EXCEPTION WHEN foreign_key_violation THEN
        NULL;
    END;

    BEGIN
        INSERT INTO mail.cached_bodies (
            tenant_id, account_id, opaque_message_id,
            encrypted_body, encrypted_dek, kms_key_resource
        ) VALUES (
            '11111111-1111-4111-8111-111111111111',
            'bbbbbbbb-0000-4000-8000-000000000002',
            decode('3b', 'hex'), decode('3c', 'hex'), decode('3d', 'hex'), 'kms://tenant-a'
        );
        RAISE EXCEPTION 'cross-tenant cached-body relation unexpectedly succeeded';
    EXCEPTION WHEN foreign_key_violation THEN
        NULL;
    END;
END
$mail_cross_tenant_relations$;

RESET ROLE;
RESET app.tenant_id;

SET ROLE atelier_worker;
SELECT set_config('app.tenant_id', '11111111-1111-4111-8111-111111111111', false);

INSERT INTO jobs.dead_letters (
    id, tenant_id, original_job_id, kind, payload, error_code, attempts
) VALUES (
    'aaaaaaaa-0000-4000-8000-000000000004',
    '11111111-1111-4111-8111-111111111111',
    'aaaaaaaa-0000-4000-8000-000000000003',
    'test', '{}', 'expected-test-error', 1
);

DO $worker_cross_tenant_relation$
BEGIN
    BEGIN
        INSERT INTO jobs.dead_letters (
            id, tenant_id, original_job_id, kind, payload, error_code, attempts
        ) VALUES (
            'aaaaaaaa-0000-4000-8000-000000000005',
            '11111111-1111-4111-8111-111111111111',
            'bbbbbbbb-0000-4000-8000-000000000003',
            'test', '{}', 'cross-tenant', 1
        );
        RAISE EXCEPTION 'cross-tenant dead-letter relation unexpectedly succeeded';
    EXCEPTION WHEN foreign_key_violation THEN
        NULL;
    END;
END
$worker_cross_tenant_relation$;

RESET ROLE;
RESET app.tenant_id;

SELECT 'tenant isolation tests passed' AS result;
