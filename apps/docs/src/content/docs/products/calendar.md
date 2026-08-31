---
title: Atelier Calendar
---

> This page describes the MVP contract. Provider adapters and the lossless ICS
> engine are not implemented in the bootstrap; see the repository
> implementation status before treating a capability as available.

The internal model preserves RFC 5545 recurrence rules, exceptions, time zones, UIDs, sequence numbers, alarms, and unknown properties. `.ics` import and export must round-trip without silently dropping fields.

Atelier can project public-compatible fields to community calendar records. The ICS UID and AT URI/CID remain linked, distinct identities; the community schema is not treated as a lossless ICS replacement.

Google Calendar, Microsoft 365, CalDAV, subscriptions, and published feeds remain source-aware. Provider events receive opaque PDS references until a person deliberately imports or publishes them.
