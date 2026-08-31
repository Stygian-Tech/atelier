---
title: MCP backplane
description: Authenticated Streamable HTTP tools and sensitive-action approvals.
---

`mcp.atelier.diy` is the planned authenticated Streamable HTTP endpoint for search, read, create, and update across Atelier domains. MyContextProtocol connector integration is deferred; the Atelier MCP service itself remains part of the MVP.

The checked-in foundation currently supports JSON `initialize`, `tools/list`, and fail-closed `tools/call` routing. Sensitive approvals are HMAC-SHA256 authenticated and bind the subject DID, exact tool name, canonical-argument digest, nonce, and expiry; nonce consumption is atomic through an injectable single-use store. The shipped bearer verifier and approval authorizer still reject every runtime token, domain executors are absent, and `/readyz` remains unavailable until all three are configured. SSE responses, session lifecycle, complete argument schemas, approval-challenge issuance, and a durable shared nonce store are still required before the service can claim Streamable HTTP execution.

The target policy requires sending mail, deleting records, sharing, changing provider connections, and equivalent actions to create an explicit approval challenge. Tool arguments must be validated before the challenge and again after approval, with the authenticated digest bound to the eventual execution. A non-null approval identifier alone is not a complete Production authorization.
