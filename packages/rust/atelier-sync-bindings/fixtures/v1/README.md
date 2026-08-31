# Collaboration wire fixtures V1

These compact UTF-8 JSON documents are byte-for-byte conformance fixtures for
Swift, Kotlin/Android, WebAssembly, and the Railway anchor. The terminating file
newline is not part of the canonical payload.

- `envelope-presence.json` is a valid deterministic V1 envelope.
- `checkpoint.json` is a deterministic checkpoint serialization with a valid
  SHA-256 integrity value for its encoded Automerge bytes.
- `envelope-corrupt-checkpoint.json` must be rejected because the nested
  checkpoint bytes do not match its integrity value.

The fixtures describe wire serialization only. They are not peer credentials,
signed invitations, live Iroh sessions, or proof of PDS durability.
