---
title: Privacy model draft
description: A pre-beta engineering draft, not final legal terms.
sidebar:
  badge: Draft
---

This page documents the engineering privacy model and is not final legal text.

Atelier separates user-owned public ATProto records from hosted provider data. Provider credentials and caches are encrypted and scoped to the linked account. Gmail bodies have a 30-day cache target; calendar provider mirrors persist only while linked. Unlinking revokes provider access and queues cache and credential purge.

Account deletion purges hosted state, indexes, and provider access. PDS record deletion is offered separately and defaults to preserving user-owned records unless the user explicitly chooses removal.
