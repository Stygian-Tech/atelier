---
title: Atelier Mail
---

> This page describes the MVP contract. The bootstrap includes protected MIME
> and History-reconciliation primitives, but no live provider adapter, OAuth
> callback, Pub/Sub consumer, or send path.

Gmail is the first daily-driver provider. JMAP follows, then IMAP/SMTP. The app presents provider-neutral threads, mailboxes, labels, drafts, search, attachments, and actions while preserving provider capabilities and source authority.

Gmail synchronization uses incremental History API processing, Pub/Sub watch renewal, idempotent jobs, periodic reconciliation, and a full-sync fallback for stale history IDs. Search joins Atelier’s encrypted cache index with provider-side results for uncached history.

Draft Markdown is canonical. Send compiles deterministic sanitized `text/plain` and `text/html` MIME parts with stable attachment encoding.
