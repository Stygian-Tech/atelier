"use client";

import { MarkdownBlockEditor } from "@stygian/markdown-editor";
import {
  ArrowRight,
  CalendarDays,
  Check,
  CheckCircle2,
  ChevronRight,
  Clock3,
  FilePlus2,
  FileText,
  FolderKanban,
  Inbox,
  Link2,
  ListTodo,
  Mail,
  MessageCircle,
  MoreHorizontal,
  Paperclip,
  Plus,
  RefreshCw,
  Search,
  Sparkles,
  Star,
  Tags,
  Users,
} from "lucide-react";
import { useMemo, useState } from "react";

import { FoundationPreviewNotice, PageHeading, ProductShell, PublicPdsNotice } from "./product-shell";

const starterNote = `# Project Atlas brief

Atelier keeps the source portable: this note is Markdown first, with the block document and collaboration state derived from it.

## Decisions

- Ship the public-data disclosure before any PDS write
- Keep provider credentials on the server
- Verify collaborator convergence separately from PDS durability

> The workshop should feel calm even when the work is complex.`;

const taskColumns = [
  { title: "Inbox", color: "var(--atelier-butter)", tasks: ["Review beta invite copy", "Connect project calendar", "Draft privacy explanation"] },
  { title: "In progress", color: "var(--atelier-cyan-soft)", tasks: ["Polish Notes editor", "Gmail sync fixtures"] },
  { title: "Done", color: "var(--atelier-coral-soft)", tasks: ["Choose public NSIDs", "Import AnyPub editor"] },
];

export function HomeWorkspace() {
  const [captured, setCaptured] = useState(false);
  return (
    <ProductShell
      current="home"
      sidebar={(
        <>
          <div className="atelier-sidebar-label">Overview</div>
          <button type="button" className="atelier-sidebar-link" data-active="true"><Sparkles size={15} /> Today</button>
          <button type="button" className="atelier-sidebar-link"><Inbox size={15} /> Inbox <span style={{ marginLeft: "auto" }}>7</span></button>
          <button type="button" className="atelier-sidebar-link"><FolderKanban size={15} /> Projects</button>
          <button type="button" className="atelier-sidebar-link"><Search size={15} /> Search</button>
        </>
      )}
    >
      <PageHeading
        eyebrow="Saturday · August 30"
        title="Good morning, Sam."
        description="A sample composed workspace showing how Home will join records owned by Notes, Mail, Calendar, and Tasks without duplicating them."
        action={<button className="atelier-button" type="button" onClick={() => setCaptured(true)}><Plus size={16} /> Quick capture</button>}
      />
      <FoundationPreviewNotice>All counts, records, and cross-app actions on this page are local fixtures; no PDS or provider mutation is connected.</FoundationPreviewNotice>
      {captured ? (
        <div className="atelier-public-notice" role="status" style={{ marginBottom: "1rem", borderColor: "var(--atelier-success)" }}>
          <CheckCircle2 size={18} /> Capture interaction previewed locally. No Inbox record was written.
        </div>
      ) : null}
      <div className="atelier-grid atelier-grid-3">
        <section className="atelier-card atelier-card-accent" style={{ "--card-accent": "var(--atelier-coral)" } as React.CSSProperties}>
          <span className="atelier-chip atelier-chip-coral"><ListTodo size={12} /> 3 due</span>
          <h2>Today</h2>
          <p>Your planned work from Tasks and Calendar, joined by typed relationships.</p>
          <ul className="atelier-list">
            <li className="atelier-list-item"><strong>Finalize Project Atlas brief</strong><span>9:30 · Atelier Notes</span></li>
            <li className="atelier-list-item"><strong>Design review</strong><span>11:00 · Atelier Calendar</span></li>
            <li className="atelier-list-item"><strong>Reply to Gmail verification thread</strong><span>Atelier Mail</span></li>
          </ul>
        </section>
        <section className="atelier-card atelier-card-accent" style={{ "--card-accent": "var(--atelier-cyan)" } as React.CSSProperties}>
          <span className="atelier-chip atelier-chip-cyan"><Inbox size={12} /> 7 items</span>
          <h2>Inbox</h2>
          <p>Unsorted captures stay portable until you deliberately convert them.</p>
          <ul className="atelier-list">
            <li className="atelier-list-item"><strong>Read RFC 5545 recurrence notes</strong><span>Captured from Mail · 8m ago</span></li>
            <li className="atelier-list-item"><strong>Ideas for the launch post</strong><span>Markdown capture · Yesterday</span></li>
            <li className="atelier-list-item"><strong>Book provider security review</strong><span>Suggested task</span></li>
          </ul>
        </section>
        <section className="atelier-card atelier-card-accent" style={{ "--card-accent": "var(--atelier-butter)" } as React.CSSProperties}>
          <span className="atelier-chip"><FolderKanban size={12} /> 4 active</span>
          <h2>Projects</h2>
          <p>Shared context connects records; it does not flatten every product into one store.</p>
          <ul className="atelier-list">
            <li className="atelier-list-item"><strong>Project Atlas</strong><span>2 notes · 5 tasks · 1 event</span></li>
            <li className="atelier-list-item"><strong>Atelier beta</strong><span>7 notes · 12 tasks · 3 events</span></li>
            <li className="atelier-list-item"><strong>Personal systems</strong><span>Private-provider refs · public PDS notes</span></li>
          </ul>
        </section>
      </div>
      <section className="atelier-card" style={{ marginTop: "1rem" }}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: "1rem", flexWrap: "wrap" }}>
          <div>
            <p className="atelier-eyebrow">Cross-app action</p>
            <h2>Turn “Launch checklist” into a task</h2>
            <p style={{ marginBottom: 0 }}>The source Note remains canonical. Atelier creates a typed relationship edge to the new Task.</p>
          </div>
          <button className="atelier-button atelier-button-secondary" type="button">Preview relationship <ArrowRight size={15} /></button>
        </div>
      </section>
    </ProductShell>
  );
}

export function NotesWorkspace() {
  const [markdown, setMarkdown] = useState(starterNote);
  const wordCount = useMemo(() => markdown.trim().split(/\s+/).filter(Boolean).length, [markdown]);
  return (
    <ProductShell
      current="notes"
      sidebar={(
        <>
          <div className="atelier-sidebar-label">Notes</div>
          <button type="button" className="atelier-sidebar-link" data-active="true"><FileText size={15} /> All notes</button>
          <button type="button" className="atelier-sidebar-link"><Star size={15} /> Favorites</button>
          <button type="button" className="atelier-sidebar-link"><Users size={15} /> Shared with me</button>
          <div className="atelier-sidebar-label">Folders</div>
          <button type="button" className="atelier-sidebar-link"><FolderKanban size={15} /> Project Atlas</button>
          <button type="button" className="atelier-sidebar-link"><Tags size={15} /> Research</button>
        </>
      )}
    >
      <PageHeading
        eyebrow="Markdown editor fixture · Service foundation"
        title="Project Atlas brief"
        description="This browser fixture edits canonical Markdown in memory. Filesystem, SQLite, collaboration, and PDS adapters are not connected yet."
        action={<button className="atelier-button" type="button"><FilePlus2 size={16} /> New note</button>}
      />
      <FoundationPreviewNotice>The editor behavior is real; the note list, collaborators, backlinks, save state, and durability rows are sample data.</FoundationPreviewNotice>
      <div className="atelier-split">
        <div>
          <PublicPdsNotice compact />
          <section className="atelier-card" style={{ marginTop: "1rem" }}>
            <p className="atelier-eyebrow">Recent</p>
            <ul className="atelier-list">
              <li className="atelier-list-item"><strong>Project Atlas brief</strong><span>Editing now · {wordCount} words</span></li>
              <li className="atelier-list-item"><strong>Calendar data model</strong><span>Yesterday · 2 backlinks</span></li>
              <li className="atelier-list-item"><strong>Launch narrative</strong><span>Friday · Named version</span></li>
            </ul>
          </section>
          <section className="atelier-card" style={{ marginTop: "1rem" }}>
            <p className="atelier-eyebrow">Durability</p>
            <ul className="atelier-list">
              <li className="atelier-list-item"><strong><Check size={13} /> Local save</strong><span>Filesystem adapter not connected</span></li>
              <li className="atelier-list-item"><strong><RefreshCw size={13} /> Collaborators</strong><span>Rust bridge and anchor not connected</span></li>
              <li className="atelier-list-item"><strong><Check size={13} /> Public PDS</strong><span>Record writer not connected</span></li>
            </ul>
          </section>
        </div>
        <div className="atelier-editor">
          <div style={{ display: "flex", alignItems: "center", gap: "0.45rem", marginBottom: "1rem", flexWrap: "wrap" }}>
            <span className="atelier-chip atelier-chip-cyan"><Users size={12} /> Presence fixture</span>
            <span className="atelier-chip"><Link2 size={12} /> Backlink fixture</span>
            <span className="atelier-chip"><Clock3 size={12} /> In-memory draft</span>
            <button type="button" className="atelier-row-button" style={{ width: "auto", marginLeft: "auto" }} aria-label="More note actions"><MoreHorizontal size={16} /></button>
          </div>
          <MarkdownBlockEditor value={markdown} onChange={setMarkdown} />
        </div>
      </div>
    </ProductShell>
  );
}

export function CalendarWorkspace() {
  const [view, setView] = useState<"week" | "agenda">("week");
  const days = [
    { label: "Mon 25", events: [{ title: "Design sync", time: "10:00", color: "var(--atelier-cyan-soft)" }] },
    { label: "Tue 26", events: [{ title: "Provider review", time: "13:30", color: "var(--atelier-coral-soft)" }] },
    { label: "Wed 27", events: [{ title: "Focus: Atlas", time: "09:00", color: "var(--atelier-butter)" }] },
    { label: "Thu 28", events: [{ title: "Community call", time: "15:00", color: "var(--atelier-cyan-soft)" }] },
    { label: "Fri 29", events: [{ title: "Beta retro", time: "11:30", color: "var(--atelier-coral-soft)" }] },
  ];
  return (
    <ProductShell
      current="calendar"
      sidebar={(
        <>
          <div className="atelier-sidebar-label">Calendar</div>
          <button type="button" className="atelier-sidebar-link" data-active="true"><CalendarDays size={15} /> Week</button>
          <button type="button" className="atelier-sidebar-link"><ListTodo size={15} /> Agenda</button>
          <div className="atelier-sidebar-label">Sources</div>
          <button type="button" className="atelier-sidebar-link"><span style={{ color: "var(--atelier-coral)" }}>●</span> Atelier</button>
          <button type="button" className="atelier-sidebar-link"><span style={{ color: "var(--atelier-cyan)" }}>●</span> Google</button>
          <button type="button" className="atelier-sidebar-link"><span style={{ color: "#b28a00" }}>●</span> ICS feeds</button>
        </>
      )}
    >
      <PageHeading
        eyebrow="RFC 5545 model target · Fixture calendar"
        title="August 25–29"
        description="The planned internal model preserves lossless recurrence and timezone data before projecting public-compatible fields to community calendar Lexicons."
        action={<button className="atelier-button" type="button"><Plus size={16} /> New event</button>}
      />
      <FoundationPreviewNotice>Events and sources on this page are fixtures; ICS parsing, provider sync, writeback, and public projection are not connected.</FoundationPreviewNotice>
      <div style={{ display: "flex", gap: "0.5rem", marginBottom: "1rem", flexWrap: "wrap" }}>
        <button className={`atelier-button ${view === "week" ? "" : "atelier-button-secondary"}`} type="button" onClick={() => setView("week")}>Week</button>
        <button className={`atelier-button ${view === "agenda" ? "" : "atelier-button-secondary"}`} type="button" onClick={() => setView("agenda")}>Agenda</button>
        <span className="atelier-chip atelier-chip-cyan" style={{ marginLeft: "auto" }}><RefreshCw size={12} /> 3 fixture sources</span>
      </div>
      <PublicPdsNotice compact />
      <section className="atelier-card" style={{ marginTop: "1rem", padding: "0.75rem" }}>
        {view === "week" ? (
          <div className="atelier-week">
            {days.map((day) => (
              <div className="atelier-day" key={day.label}>
                <strong style={{ fontSize: "0.75rem" }}>{day.label}</strong>
                {day.events.map((event) => (
                  <div className="atelier-event" style={{ "--event-color": event.color } as React.CSSProperties} key={event.title}>
                    <span className="atelier-meta">{event.time}</span><br />{event.title}
                  </div>
                ))}
              </div>
            ))}
          </div>
        ) : (
          <ul className="atelier-list">
            {days.flatMap((day) => day.events.map((event) => (
              <li className="atelier-list-item" key={`${day.label}-${event.title}`}><strong>{event.title}</strong><span>{day.label} · {event.time}</span></li>
            )))}
          </ul>
        )}
      </section>
      <div className="atelier-grid atelier-grid-3" style={{ marginTop: "1rem" }}>
        <section className="atelier-card"><span className="atelier-chip">ICS</span><h2>Round-trip target</h2><p>The parser must preserve UID, sequence, recurrence exceptions, alarms, zones, and unknown properties.</p></section>
        <section className="atelier-card"><span className="atelier-chip atelier-chip-cyan">Provider</span><h2>Source-owned</h2><p>Google, Microsoft, CalDAV, and feed events stay authoritative until explicitly imported.</p></section>
        <section className="atelier-card"><span className="atelier-chip atelier-chip-coral">ATProto</span><h2>Public projection</h2><p>Public-compatible fields can link an AT URI/CID without replacing the ICS identity.</p></section>
      </div>
    </ProductShell>
  );
}

export function TasksWorkspace() {
  const [complete, setComplete] = useState<Record<string, boolean>>({ "Choose public NSIDs": true, "Import AnyPub editor": true });
  return (
    <ProductShell
      current="tasks"
      sidebar={(
        <>
          <div className="atelier-sidebar-label">Tasks</div>
          <button type="button" className="atelier-sidebar-link" data-active="true"><Inbox size={15} /> Inbox <span style={{ marginLeft: "auto" }}>3</span></button>
          <button type="button" className="atelier-sidebar-link"><CheckCircle2 size={15} /> Today</button>
          <button type="button" className="atelier-sidebar-link"><CalendarDays size={15} /> Upcoming</button>
          <div className="atelier-sidebar-label">Projects</div>
          <button type="button" className="atelier-sidebar-link"><FolderKanban size={15} /> Atelier beta</button>
          <button type="button" className="atelier-sidebar-link"><FolderKanban size={15} /> Project Atlas</button>
        </>
      )}
    >
      <PageHeading
        eyebrow="Collaborative project fixture · Service foundation"
        title="Atelier beta"
        description="This board previews owner-canonical tasks, scoped collaborator mutations, field-level offline operations, and surfaced destructive conflicts."
        action={<button className="atelier-button" type="button"><Plus size={16} /> Add task</button>}
      />
      <FoundationPreviewNotice>Board items, members, comments, attachments, and queue state are local fixtures; no owner PDS or collaborator mutation is connected.</FoundationPreviewNotice>
      <PublicPdsNotice compact />
      <section className="atelier-board" aria-label="Atelier beta task board" style={{ marginTop: "1rem" }}>
        {taskColumns.map((column) => (
          <div className="atelier-board-column" key={column.title}>
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
              <strong style={{ fontSize: "0.78rem" }}>{column.title}</strong>
              <span className="atelier-chip" style={{ background: column.color }}>{column.tasks.length}</span>
            </div>
            {column.tasks.map((task) => (
              <article className="atelier-task" key={task}>
                <label>
                  <input type="checkbox" checked={Boolean(complete[task])} onChange={(event) => setComplete((current) => ({ ...current, [task]: event.target.checked }))} />
                  <span style={{ textDecoration: complete[task] ? "line-through" : "none" }}>{task}</span>
                </label>
                <div style={{ display: "flex", gap: "0.45rem", marginTop: "0.65rem" }}>
                  <span className="atelier-chip"><MessageCircle size={11} /> 2</span>
                  <span className="atelier-chip"><Paperclip size={11} /> 1</span>
                  <span className="atelier-chip atelier-chip-coral" style={{ marginLeft: "auto" }}>P1</span>
                </div>
              </article>
            ))}
          </div>
        ))}
      </section>
      <section className="atelier-card" style={{ marginTop: "1rem" }}>
        <p className="atelier-eyebrow">Offline operation queue</p>
        <div style={{ display: "flex", gap: "0.6rem", alignItems: "center", flexWrap: "wrap" }}>
          <span className="atelier-chip atelier-chip-cyan"><CheckCircle2 size={12} /> Adapter not connected</span>
          <span className="atelier-chip"><RefreshCw size={12} /> Local checkbox state</span>
          <span className="atelier-meta">The intended merge policy handles independent fields automatically and pauses destructive collisions for review.</span>
          <button type="button" className="atelier-row-button" style={{ width: "auto", marginLeft: "auto" }}>Inspect queue <ChevronRight size={14} /></button>
        </div>
      </section>
    </ProductShell>
  );
}
