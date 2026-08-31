---
title: Atelier Tasks
---

> This page describes the MVP contract. The bootstrap UI and record contracts
> do not yet provide a durable task engine or collaboration service.

Tasks includes projects, Inbox, sections, subtasks, dependencies, recurrence, reminders, assignments, comments, attachments, tags, saved views, and list/board/calendar presentation.

Offline changes are idempotent field-level operations. Independent edits merge; CAS revisions stop destructive collisions for review. Canonical records stay in the owner’s PDS and scoped collaborator mutations are mediated through the owner-authorized service session.
