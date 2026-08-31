# Atelier Calendar sync boundary

Calendar sync will consume durable jobs for Google Calendar, Microsoft Graph, and CalDAV. Source authority is explicit: provider/feed records remain provider/feed-owned, while imported or Atelier-created events are PDS-owned.

The Swift service now names five source surfaces explicitly: ICS subscriptions, community calendars, Google Calendar, Microsoft Graph, and CalDAV. Its capability catalog keeps subscription feeds read-only and provider sources provider-owned. Typed durable job envelopes carry protected source/cursor identifiers only; titles, locations, attendees, and raw iCalendar are rejected at that queue seam.

The executable, configuration validation, executor registry, and job handlers are implemented, but source adapters and the Postgres job-store adapter are not. No live calendar or feed call is made. Readiness remains false until selected adapters exist. Implementations must preserve complete iCalendar data, recurrence exceptions, sequence, time zones, alarms, unknown properties, provider sync tokens, and optimistic source versions before writeback is enabled.
