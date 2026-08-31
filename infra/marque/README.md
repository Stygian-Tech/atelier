# Marque DNS change sets

Marque remains authoritative for every `atelier.diy` record. The JSON files are
reviewable change-set manifests, not credentials and not an executable Marque
API format. Both are intentionally `apply: false`; Production also carries an
explicit approval guard.

Marque supports CNAME flattening, so the Production apex can follow Railway's
CNAME target without an illegal DNS apex CNAME. Exact targets and ownership TXT
records are generated only after each custom domain is attached in Railway.

Apply workflow:

1. Export and retain the complete current Marque zone.
2. Attach the Development hostnames in Railway and copy exact targets/TXT values.
3. Replace all placeholders, add verification records, and validate there are no
   duplicate or conflicting names.
4. Review one full diff that preserves unrelated records and current mail/ATProto
   records.
5. Apply the Development transaction in Marque, then verify authoritative DNS,
   certificates, direct HTTP, OAuth metadata, webhook callbacks, and app behavior.
6. Leave Production untouched until a separate final approval and rollback plan.

Never put Marque sessions, ATProto tokens, Railway tokens, or DNSSEC key material
in these files.
