import { describe, expect, test } from "bun:test";
import { renderToStaticMarkup } from "react-dom/server";

import { CalendarWorkspace, HomeWorkspace, NotesWorkspace, TasksWorkspace } from "../src";

describe("Atelier product workspace shells", () => {
  test("Home composes each focused product without claiming a duplicate store", () => {
    const html = renderToStaticMarkup(<HomeWorkspace />);
    expect(html).toContain("Good morning, Sam.");
    expect(html).toContain("Atelier Notes");
    expect(html).toContain("Atelier Mail");
    expect(html).toContain("Atelier Calendar");
    expect(html).toContain("All counts, records, and cross-app actions on this page are local fixtures");
    expect(html).toContain("does not flatten every product into one store");
  });

  test("Notes distinguishes public PDS, local save, convergence, and durability", () => {
    const html = renderToStaticMarkup(<NotesWorkspace />);
    expect(html).toContain("Public PDS");
    expect(html).toContain("Local save");
    expect(html).toContain("Collaborators");
    expect(html).toContain("Rust bridge and anchor not connected");
    expect(html).not.toContain("2 peers converged");
    expect(html).toContain("data-testid=\"markdown-block-editor\"");
  });

  test("Calendar explains source fidelity and Tasks explains offline conflict handling", () => {
    const calendar = renderToStaticMarkup(<CalendarWorkspace />);
    const tasks = renderToStaticMarkup(<TasksWorkspace />);
    expect(calendar).toContain("RFC 5545 model target");
    expect(calendar).toContain("Round-trip target");
    expect(calendar).not.toContain("sources synced");
    expect(tasks).toContain("Offline operation queue");
    expect(tasks).toContain("Local checkbox state");
    expect(tasks).toContain("pauses destructive collisions for review");
  });
});
