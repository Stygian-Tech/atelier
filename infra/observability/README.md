# Observability and redaction

Atelier emits OpenTelemetry traces/metrics and redacted Sentry errors. Telemetry
must describe operations, latency, outcomes, queue age, retries, and degradation;
it must never become a second content store.

## Required SDK behavior

- Set `service.name`, `service.version`, `deployment.environment`, trace/span ID,
  operation name, outcome, and coarse provider/domain labels.
- HMAC-hash DIDs, account IDs, document IDs, and project IDs with an
  environment-specific observability key before export. Never use an unhashed
  email address as an identifier.
- Do not attach Markdown, mail/event/task/note content, Automerge frames,
  attachments, provider payloads, OAuth material, cookies, DPoP proofs, SQL
  statements, query values, or request/response bodies.
- Use bounded, enumerated error reasons. Unknown upstream text is local-only;
  export a classified code plus exception type and a scrubbed stack.
- Record security/audit events in the dedicated 90-day audit store, not Sentry
  breadcrumbs. Audit metadata follows the same content prohibition.

## Sentry gates

Every client and service must set `sendDefaultPii = false`, disable request body
capture, and install `beforeSend` and `beforeBreadcrumb` hooks implementing
`redaction-policy.toml`. Hooks recursively drop forbidden keys, apply the header
allowlist, scrub URLs to path templates, truncate messages, remove local
variables, and hash approved correlation identifiers. A test containing canary
secrets and representative Notes/Mail/Calendar content must prove the exported
event contains none of them.

Source maps and debug symbols may be uploaded by CI with provider tokens held in
CI secrets; the artifacts and upload logs must not embed runtime environment
values.

## Collector boundary

`otel-collector.example.yaml` is a defense-in-depth baseline, not a deployment.
The SDK must redact first because a collector cannot reliably understand every
language-specific body or breadcrumb shape. Add logs only after a separate
allowlist review; the baseline intentionally exports traces and metrics only.
