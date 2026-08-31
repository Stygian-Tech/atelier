# Atelier MCP backplane

This bootstrap exposes JSON-RPC requests over `POST /mcp` with `application/json`. It does not yet implement MCP Streamable HTTP sessions, resumability, or SSE delivery; those remain target capabilities rather than current transport claims.

OAuth bearer verification establishes the subject and granted scopes. Sensitive-write tools require an additional authenticated approval token whose HMAC-SHA256 payload binds the exact subject DID, case-sensitive tool name, SHA-256 digest of canonical JSON arguments, random nonce, and expiry. The nonce is consumed atomically through `MCPSingleUseApprovalStore` before execution. Production must provide a durable store shared by every backplane replica; an in-process set is suitable only for deterministic tests.

Missing, malformed, mismatched, expired, replayed, or store-unavailable approvals all fail closed with the same external JSON-RPC error. Read and ordinary write tools retain their existing scope checks and do not depend on approval verification. The bootstrap still ships rejecting auth/approval implementations and an unavailable executor, so readiness remains false until all three are deliberately configured.
