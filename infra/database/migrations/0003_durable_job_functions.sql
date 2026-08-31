BEGIN;

CREATE FUNCTION jobs.enqueue(
    p_tenant_id uuid,
    p_kind text,
    p_idempotency_key text,
    p_payload jsonb,
    p_not_before timestamptz DEFAULT now(),
    p_max_attempts integer DEFAULT 10
) RETURNS jobs.queue
LANGUAGE plpgsql AS $$
DECLARE
    result jobs.queue;
BEGIN
    INSERT INTO jobs.queue (tenant_id, kind, idempotency_key, payload, not_before, max_attempts)
    VALUES (p_tenant_id, p_kind, p_idempotency_key, p_payload, p_not_before, p_max_attempts)
    ON CONFLICT (tenant_id, kind, idempotency_key) DO UPDATE
      SET idempotency_key = EXCLUDED.idempotency_key
    RETURNING * INTO result;
    RETURN result;
END
$$;

CREATE FUNCTION jobs.lease_next(
    p_worker_id text,
    p_kinds text[],
    p_lease interval DEFAULT interval '60 seconds'
) RETURNS jobs.queue
LANGUAGE plpgsql AS $$
DECLARE
    result jobs.queue;
BEGIN
    WITH candidate AS (
        SELECT id
        FROM jobs.queue
        WHERE tenant_id = platform.current_tenant_id()
          AND kind = ANY (p_kinds)
          AND state = 'pending'
          AND not_before <= now()
        ORDER BY not_before, created_at
        FOR UPDATE SKIP LOCKED
        LIMIT 1
    )
    UPDATE jobs.queue q
       SET state = 'leased',
           lease_owner = p_worker_id,
           lease_expires_at = now() + p_lease,
           attempts = attempts + 1,
           updated_at = now()
      FROM candidate
     WHERE q.id = candidate.id
    RETURNING q.* INTO result;
    RETURN result;
END
$$;

CREATE FUNCTION jobs.complete(p_job_id uuid, p_worker_id text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE jobs.queue
       SET state = 'succeeded', lease_owner = NULL, lease_expires_at = NULL, updated_at = now()
     WHERE id = p_job_id AND tenant_id = platform.current_tenant_id()
       AND state = 'leased' AND lease_owner = p_worker_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'job lease is not owned by worker'; END IF;
END
$$;

CREATE FUNCTION jobs.retry(
    p_job_id uuid,
    p_worker_id text,
    p_not_before timestamptz,
    p_error_code text
) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE jobs.queue
       SET state = 'pending', lease_owner = NULL, lease_expires_at = NULL,
           not_before = p_not_before, last_error_code = p_error_code, updated_at = now()
     WHERE id = p_job_id AND tenant_id = platform.current_tenant_id()
       AND state = 'leased' AND lease_owner = p_worker_id AND attempts < max_attempts;
    IF NOT FOUND THEN RAISE EXCEPTION 'job cannot be retried by worker'; END IF;
END
$$;

CREATE FUNCTION jobs.dead_letter(p_job_id uuid, p_worker_id text, p_error_code text) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
    failed jobs.queue;
BEGIN
    UPDATE jobs.queue
       SET state = 'dead', lease_owner = NULL, lease_expires_at = NULL,
           last_error_code = p_error_code, updated_at = now()
     WHERE id = p_job_id AND tenant_id = platform.current_tenant_id()
       AND state = 'leased' AND lease_owner = p_worker_id
    RETURNING * INTO failed;
    IF failed.id IS NULL THEN RAISE EXCEPTION 'job lease is not owned by worker'; END IF;

    INSERT INTO jobs.dead_letters (tenant_id, original_job_id, kind, payload, error_code, attempts)
    VALUES (failed.tenant_id, failed.id, failed.kind, failed.payload, p_error_code, failed.attempts)
    ON CONFLICT (tenant_id, original_job_id) DO NOTHING;
END
$$;

COMMIT;
