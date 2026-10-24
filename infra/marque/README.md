# Marque DNS change sets

Marque remains authoritative for every `atelier.diy` record. The JSON files are
reviewable change-set manifests, not credentials and not an executable Marque
API format. Both are intentionally `apply: false`; Production also carries an
explicit approval guard.

Marque supports CNAME flattening, so the Production apex can follow Railway's
CNAME target without an illegal DNS apex CNAME. Exact targets and ownership TXT
records are generated only after each custom domain is attached in Railway.

The Development and Production manifests contain only the eight currently
deployed public surfaces. API and MCP records remain absent until those services
pass their readiness gates and are actually provisioned. The eight-surface
Production foundation preview was explicitly authorized and applied through one
reviewed Marque transaction on 2026-08-31. Certificate verification remains a
separate Railway gate. This approval does not extend to the unfinished services
or provider callback cutovers. Railway targets and ownership tokens are public
DNS material, not application credentials, but they must still be rechecked
against Railway immediately before each Marque transaction.

Apply workflow:

1. Export and retain the complete current Marque zone.
2. Attach the selected environment's hostnames in Railway and copy exact
   targets/TXT values.
3. Validate the captured records have no placeholders, duplicates, undeployed
   services, or conflicts with the current zone.
4. Review one full diff that preserves unrelated records and current mail/ATProto
   records.
5. Apply one environment transaction in Marque, then verify authoritative DNS,
   certificates, direct HTTP, OAuth metadata, webhook callbacks, and app behavior.
6. Keep API, MCP, provider callbacks, and every other unfinished surface absent
   until its own readiness and approval gate passes.

Never put Marque sessions, ATProto tokens, Railway tokens, or DNSSEC key material
in these files.
