# Google Cloud foundation

This Terraform scaffold defines one isolated Google Cloud project per Atelier
environment with:

- a 90-day rotating Cloud KMS key for application envelope keys and bucket CMEK;
- a 30-day provider-cache bucket plus a versioned durable attachment/export bucket;
- a Gmail Pub/Sub topic and pull subscription;
- the required Gmail system publisher grant;
- a keyless runtime service account and optional, exact-subject workload OIDC trust.

Every example keeps `enable_resources = false`. A reviewed Development apply is
a separate external action; Production requires its own explicit approval. The
module never creates or exports a service-account key.

The optional workload identity provider must not be enabled merely because
Railway offers account-login OIDC. Confirm that the deployed workload can mint
a suitable, audience-bound workload token, then set the exact issuer, audience,
and subject. Otherwise use a separately approved secret delivery mechanism and
keep the provider disabled.

Provider bodies placed in the cache bucket expire after 30 days. Applications
remain responsible for deleting all account objects and wrapped data keys on
unlink; bucket lifecycle is a backstop, not the unlink workflow.

```sh
terraform -chdir=infra/gcp init
terraform -chdir=infra/gcp fmt -check -recursive
terraform -chdir=infra/gcp validate
terraform -chdir=infra/gcp plan -var-file=development.tfvars
```
