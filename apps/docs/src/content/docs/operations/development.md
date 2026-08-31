---
title: Local and Development environments
---

Use the toolchain versions in the repository `mise.toml`, run `bun install`, and start local supporting services from `infra/docker` before running product or service processes.

Railway `Development` is persistent and deploys from `dev`. Provider credentials are never added to selective pull-request environments. Guarded migrations run before readiness.

Production deployment, OAuth callback cutovers, provider webhook cutovers, and Marque production DNS changes require separate explicit approval.
