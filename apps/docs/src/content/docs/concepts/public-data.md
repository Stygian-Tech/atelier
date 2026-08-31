---
title: Public data and privacy boundaries
description: What is public, what remains protected, and how Atelier discloses the difference.
sidebar:
  order: 1
---

> This page defines the MVP data boundary. The bootstrap currently writes only
> named local preview data; no hosted PDS write, provider cache, or Permissioned
> Spaces migration is connected.

Atelier’s interim first-party storage model uses ordinary ATProto repositories. Ordinary repositories are public and readable. User-scoped AppView discovery reduces accidental surfacing; it does **not** make a record private.

:::danger[Do not place secrets in first-party records]
Notes, tasks, Atelier-created events, projects, captures, comments, and relationship edges must be treated as public until they are migrated to an enabled Permissioned Space.
:::

## Content written to the PDS

- canonical Markdown and metadata for first-party notes;
- owner-canonical tasks and projects;
- Atelier-created or explicitly imported calendar events;
- actor-owned comments, RSVPs, and typed relationship edges;
- opaque provider references without subjects, participants, snippets, titles, locations, or bodies.

Every affected creation surface shows a **Public PDS** disclosure before the write. Existing records keep a visible status badge.

## Content kept server-side

Provider OAuth tokens, Gmail content, provider calendar mirrors, provider search results, encryption keys, and provider webhook state must remain on Atelier-controlled services. The target implementation uses envelope encryption, bounded cache retention, and purge-on-unlink behavior.

## Permissioned Spaces migration

The planned adapter is capability-detected and disabled by default. A migration copies content and edges into a Space, verifies the copy, switches canonical references, and only then deletes the public record. The UI warns that earlier mirrors may still retain it.
