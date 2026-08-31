"use client";

import {
  Archive,
  Braces,
  ChevronLeft,
  Clock3,
  Command,
  Database,
  FileText,
  Inbox,
  Keyboard,
  Mail,
  MailCheck,
  Menu,
  Moon,
  MoreHorizontal,
  PenLine,
  RefreshCw,
  Search,
  Send,
  Sparkles,
  Star,
  Sun,
  Tags,
  Trash2,
  X,
} from "lucide-react";
import * as React from "react";
import { useVirtualizer } from "@tanstack/react-virtual";
import { MarkdownBlockEditor } from "@stygian/markdown-editor";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import { shouldShowDebugChrome, type AppEnv } from "@/lib/appEnv";
import { cn } from "@/lib/utils";
import { accounts, threads as initialThreads } from "./sampleData";
import type { ComposerDraft, MailThread } from "./types";

type ColorMode = "light" | "dark";
type MobilePane = "list" | "reader";

const THEME_STORAGE_KEY = "atelier-mail-theme";
const SIDEBAR_WIDTH_STORAGE_KEY = "atelier-mail-sidebar-width-rem";
const THREAD_WIDTH_STORAGE_KEY = "atelier-mail-thread-width-rem";

const SIDEBAR_WIDTH = { default: 15.75, min: 13.5, max: 20 };
const THREAD_WIDTH = { default: 28, min: 20, max: 36 };

function emptyDraft(thread?: MailThread): ComposerDraft {
  return {
    to: thread?.email ?? "",
    subject: thread ? `Re: ${thread.subject}` : "",
    body: "",
  };
}

function isColorMode(value: string | null): value is ColorMode {
  return value === "light" || value === "dark";
}

function readInitialTheme(): ColorMode {
  if (typeof window === "undefined") return "light";

  try {
    const storedTheme = window.localStorage.getItem(THEME_STORAGE_KEY);
    if (isColorMode(storedTheme)) return storedTheme;
    return window.matchMedia?.("(prefers-color-scheme: dark)").matches ? "dark" : "light";
  } catch {
    return "light";
  }
}

function clamp(value: number, min: number, max: number) {
  return Math.min(max, Math.max(min, value));
}

function readStoredRemWidth(key: string, fallback: number, min: number, max: number) {
  if (typeof window === "undefined") return fallback;

  try {
    const parsed = Number.parseFloat(window.localStorage.getItem(key) ?? "");
    return Number.isFinite(parsed) ? clamp(parsed, min, max) : fallback;
  } catch {
    return fallback;
  }
}

function readStoredSidebarWidth() {
  return readStoredRemWidth(
    SIDEBAR_WIDTH_STORAGE_KEY,
    SIDEBAR_WIDTH.default,
    SIDEBAR_WIDTH.min,
    SIDEBAR_WIDTH.max
  );
}

function readStoredThreadWidth() {
  return readStoredRemWidth(
    THREAD_WIDTH_STORAGE_KEY,
    THREAD_WIDTH.default,
    THREAD_WIDTH.min,
    THREAD_WIDTH.max
  );
}

function subscribeToBrowserPreferences(onStoreChange: () => void) {
  window.addEventListener("storage", onStoreChange);
  return () => window.removeEventListener("storage", onStoreChange);
}

function emptySubscription() {
  return () => {};
}

function browserPreferencesReady() {
  return true;
}

function serverPreferencesPending() {
  return false;
}

function serverTheme(): ColorMode {
  return "light";
}

function serverSidebarWidth() {
  return SIDEBAR_WIDTH.default;
}

function serverThreadWidth() {
  return THREAD_WIDTH.default;
}

function rootRemPx() {
  if (typeof window === "undefined") return 16;
  return Number.parseFloat(window.getComputedStyle(document.documentElement).fontSize) || 16;
}

export function MailWorkspace({ appEnv }: { appEnv: AppEnv }) {
  const [threads, setThreads] = React.useState(initialThreads);
  const storedTheme = React.useSyncExternalStore(subscribeToBrowserPreferences, readInitialTheme, serverTheme);
  const storedSidebarWidth = React.useSyncExternalStore(
    subscribeToBrowserPreferences,
    readStoredSidebarWidth,
    serverSidebarWidth
  );
  const storedThreadWidth = React.useSyncExternalStore(
    subscribeToBrowserPreferences,
    readStoredThreadWidth,
    serverThreadWidth
  );
  const preferencesHydrated = React.useSyncExternalStore(
    emptySubscription,
    browserPreferencesReady,
    serverPreferencesPending
  );
  const [themeOverride, setThemeOverride] = React.useState<ColorMode | null>(null);
  const [sidebarWidthOverride, setSidebarWidthOverride] = React.useState<number | null>(null);
  const [threadWidthOverride, setThreadWidthOverride] = React.useState<number | null>(null);
  const theme = themeOverride ?? storedTheme;
  const sidebarWidthRem = sidebarWidthOverride ?? storedSidebarWidth;
  const threadWidthRem = threadWidthOverride ?? storedThreadWidth;
  const [selectedMailbox, setSelectedMailbox] = React.useState("inbox");
  const [selectedAccount, setSelectedAccount] = React.useState<string>("all");
  const [selectedThreadId, setSelectedThreadId] = React.useState(initialThreads[0]?.id ?? "");
  const [query, setQuery] = React.useState("");
  const [composeOpen, setComposeOpen] = React.useState(true);
  const [sidebarOpen, setSidebarOpen] = React.useState(false);
  const [mobilePane, setMobilePane] = React.useState<MobilePane>("list");
  const [previewActionMessage, setPreviewActionMessage] = React.useState("");

  const [draft, setDraft] = React.useState<ComposerDraft>(() => emptyDraft(initialThreads[0]));

  const visibleThreads = React.useMemo(() => {
    return threads.filter((thread) => {
      const accountMatch = selectedAccount === "all" || thread.accountId === selectedAccount;
      const mailboxMatch =
        selectedMailbox === "inbox" ||
        (selectedMailbox === "starred" && thread.starred) ||
        (selectedMailbox === "archive" && false) ||
        selectedMailbox === "drafts" ||
        selectedMailbox === "sent";
      const text = `${thread.from} ${thread.subject} ${thread.snippet} ${thread.labels.join(" ")}`.toLowerCase();
      const queryMatch = query.trim().length === 0 || text.includes(query.toLowerCase());
      return accountMatch && mailboxMatch && queryMatch;
    });
  }, [query, selectedAccount, selectedMailbox, threads]);

  const effectiveSelectedThreadId = visibleThreads.some((thread) => thread.id === selectedThreadId)
    ? selectedThreadId
    : visibleThreads[0]?.id ?? "";
  const selectedThread = threads.find((thread) => thread.id === effectiveSelectedThreadId) ?? visibleThreads[0];
  const showDebugChrome = shouldShowDebugChrome(appEnv);

  React.useEffect(() => {
    if (!preferencesHydrated) return;

    document.documentElement.classList.toggle("dark", theme === "dark");
    document.documentElement.dataset.theme = theme;
    if (themeOverride === null) return;

    try {
      window.localStorage.setItem(THEME_STORAGE_KEY, theme);
    } catch {
      // Ignore private browsing or storage-disabled environments.
    }
  }, [preferencesHydrated, theme, themeOverride]);

  React.useEffect(() => {
    if (!preferencesHydrated || sidebarWidthOverride === null) return;

    try {
      window.localStorage.setItem(SIDEBAR_WIDTH_STORAGE_KEY, sidebarWidthRem.toFixed(3));
    } catch {
      // Ignore private browsing or storage-disabled environments.
    }
  }, [preferencesHydrated, sidebarWidthOverride, sidebarWidthRem]);

  React.useEffect(() => {
    if (!preferencesHydrated || threadWidthOverride === null) return;

    try {
      window.localStorage.setItem(THREAD_WIDTH_STORAGE_KEY, threadWidthRem.toFixed(3));
    } catch {
      // Ignore private browsing or storage-disabled environments.
    }
  }, [preferencesHydrated, threadWidthOverride, threadWidthRem]);

  function startColumnResize(
    event: React.PointerEvent,
    initialWidthRem: number,
    minWidthRem: number,
    maxWidthRem: number,
    onResize: (widthRem: number) => void
  ) {
    event.preventDefault();
    event.currentTarget.setPointerCapture(event.pointerId);

    const startX = event.clientX;
    const remPx = rootRemPx();

    function handlePointerMove(moveEvent: PointerEvent) {
      const deltaRem = (moveEvent.clientX - startX) / remPx;
      onResize(clamp(initialWidthRem + deltaRem, minWidthRem, maxWidthRem));
    }

    function handlePointerUp() {
      window.removeEventListener("pointermove", handlePointerMove);
      window.removeEventListener("pointerup", handlePointerUp);
    }

    window.addEventListener("pointermove", handlePointerMove);
    window.addEventListener("pointerup", handlePointerUp, { once: true });
  }

  function togglePreviewStar(threadId: string) {
    setThreads((current) =>
      current.map((thread) =>
        thread.id === threadId ? { ...thread, starred: !thread.starred } : thread
      )
    );
    setPreviewActionMessage("Star updated only in this browser fixture. No provider or PDS record was changed.");
  }

  function openReply() {
    setDraft(emptyDraft(selectedThread));
    setComposeOpen(true);
  }

  return (
    <main
      className="flex h-[calc(100dvh-var(--environment-banner-height,0px))] flex-col overflow-hidden bg-background text-foreground"
      style={{ color: "var(--foreground)" }}
    >
      <PreviewBoundary actionMessage={previewActionMessage} />
      <div className="relative flex min-h-0 flex-1 overflow-hidden border bg-card/95 shadow-[0_10px_36px_rgba(67,54,47,0.08)] backdrop-blur">
        <aside
          className={cn(
            "absolute inset-y-0 left-0 z-20 shrink-0 border-r bg-sidebar transition-transform md:static md:z-auto md:translate-x-0",
            sidebarOpen ? "translate-x-0" : "-translate-x-[calc(100%+1rem)]"
          )}
          style={{ width: `${sidebarWidthRem}rem` }}
        >
          <SidebarContent
            selectedMailbox={selectedMailbox}
            selectedAccount={selectedAccount}
            theme={theme}
            onSelectMailbox={(id) => {
              setSelectedMailbox(id);
              setSidebarOpen(false);
              setMobilePane("list");
            }}
            onSelectAccount={(id) => {
              setSelectedAccount(id);
              setSidebarOpen(false);
              setMobilePane("list");
            }}
            onToggleTheme={() => setThemeOverride(theme === "dark" ? "light" : "dark")}
            onClose={() => setSidebarOpen(false)}
          />
        </aside>

        <section className="flex min-w-0 flex-1">
          <ColumnResizeHandle
            ariaLabel="Resize sidebar"
            onPointerDown={(event) =>
              startColumnResize(
                event,
                sidebarWidthRem,
                SIDEBAR_WIDTH.min,
                SIDEBAR_WIDTH.max,
                setSidebarWidthOverride
              )
            }
          />
          <ThreadColumn
            query={query}
            selectedThreadId={effectiveSelectedThreadId}
            theme={theme}
            widthRem={threadWidthRem}
            threads={visibleThreads}
            mobileReaderOpen={mobilePane === "reader"}
            onOpenSidebar={() => setSidebarOpen(true)}
            onQueryChange={setQuery}
            onSelectThread={(id) => {
              setSelectedThreadId(id);
              setMobilePane("reader");
            }}
            onToggleStar={togglePreviewStar}
          />
          <ColumnResizeHandle
            ariaLabel="Resize thread list"
            onPointerDown={(event) =>
              startColumnResize(
                event,
                threadWidthRem,
                THREAD_WIDTH.min,
                THREAD_WIDTH.max,
                setThreadWidthOverride
              )
            }
          />

          <ReaderPane
            composeOpen={composeOpen}
            draft={draft}
            showDebugChrome={showDebugChrome}
            theme={theme}
            thread={selectedThread}
            mobileOpen={mobilePane === "reader"}
            onBack={() => setMobilePane("list")}
            onCloseCompose={() => setComposeOpen(false)}
            onDraftChange={setDraft}
            onReply={openReply}
            onToggleStar={() => selectedThread && togglePreviewStar(selectedThread.id)}
          />
        </section>
      </div>
    </main>
  );
}

function PreviewBoundary({ actionMessage }: { actionMessage: string }) {
  return (
    <section
      aria-labelledby="mail-preview-boundary-title"
      className="border-b border-amber-400/45 bg-amber-50 px-3 py-2 text-amber-950 dark:border-amber-500/35 dark:bg-amber-950 dark:text-amber-50"
      role="note"
    >
      <div className="mx-auto flex max-w-7xl flex-wrap items-baseline gap-x-2 gap-y-1 text-xs leading-5">
        <strong id="mail-preview-boundary-title" className="font-black">
          Foundation preview — no provider actions
        </strong>
        <span id="mail-preview-boundary">
          This inbox is fixture data. Provider sync, delivery, archive, delete, snooze, and refresh are not connected.
          Provider mail stays protected server-side; public PDS records contain only opaque references.
        </span>
        <span aria-live="polite" className="font-semibold" role="status">
          {actionMessage}
        </span>
      </div>
    </section>
  );
}

function SidebarContent({
  selectedMailbox,
  selectedAccount,
  theme,
  onSelectMailbox,
  onSelectAccount,
  onToggleTheme,
  onClose,
}: {
  selectedMailbox: string;
  selectedAccount: string;
  theme: "light" | "dark";
  onSelectMailbox: (id: string) => void;
  onSelectAccount: (id: string) => void;
  onToggleTheme: () => void;
  onClose: () => void;
}) {
  return (
    <div className="flex h-full flex-col bg-sidebar text-sidebar-foreground">
      <div className="flex items-center justify-between gap-2 border-b px-2.5 py-2">
        <div className="flex min-w-0 items-center gap-2">
          <div className="atelier-shimmer grid size-7 place-items-center rounded-md bg-[linear-gradient(135deg,var(--primary),#ffc857,#22b8cf)] text-xs font-black text-white shadow-[0_10px_24px_rgba(255,101,66,0.18)]">
            A
          </div>
          <div className="min-w-0">
            <div className="truncate text-xs font-black leading-4">Atelier Mail</div>
            <div className="truncate text-[0.625rem] font-medium leading-3 text-muted-foreground">sam.atelier.diy</div>
          </div>
        </div>
        <div className="flex items-center gap-1">
          <Button
            aria-label={theme === "dark" ? "Switch to light mode" : "Switch to dark mode"}
            className="size-7 text-primary"
            size="icon"
            title={theme === "dark" ? "Light mode" : "Dark mode"}
            variant="ghost"
            onClick={onToggleTheme}
          >
            {theme === "dark" ? <Sun /> : <Moon />}
          </Button>
          <Button aria-label="Close sidebar" className="size-6 md:hidden" size="icon" variant="ghost" onClick={onClose}>
            <X />
          </Button>
        </div>
      </div>

      <div className="flex flex-1 flex-col gap-3 overflow-y-auto px-1.5 py-2">
        <nav className="flex flex-col gap-1">
          <SidebarAction icon={Inbox} label="Unified Inbox" active={selectedMailbox === "inbox"} count={16} onClick={() => onSelectMailbox("inbox")} />
          <SidebarAction icon={Star} label="Starred" active={selectedMailbox === "starred"} count={5} onClick={() => onSelectMailbox("starred")} />
          <SidebarAction icon={PenLine} label="Drafts" active={selectedMailbox === "drafts"} count={2} onClick={() => onSelectMailbox("drafts")} />
          <SidebarAction icon={Archive} label="Archive" active={selectedMailbox === "archive"} onClick={() => onSelectMailbox("archive")} />
        </nav>

        <section className="flex flex-col gap-1">
          <div className="mail-sidebar-section-label px-1.5 py-0.5 font-bold uppercase tracking-[0.12em] text-muted-foreground">Accounts</div>
          <SidebarAction icon={Mail} label="All accounts" active={selectedAccount === "all"} count={16} onClick={() => onSelectAccount("all")} />
          {accounts.map((account) => (
            <button
              key={account.id}
              className={cn(
                "mail-sidebar-account flex min-h-[1.75rem] items-center gap-1.5 rounded-md px-1.5 text-left transition-colors hover:bg-primary/10",
                selectedAccount === account.id && "bg-primary/10 font-semibold text-foreground"
              )}
              onClick={() => onSelectAccount(account.id)}
              type="button"
            >
              <span className="size-2 rounded-full" style={{ backgroundColor: account.accent }} />
              <span className="min-w-0 flex-1">
                <span className="block truncate">{account.name}</span>
                <span className="mail-sidebar-meta block truncate text-muted-foreground">{account.address}</span>
              </span>
              {account.unread > 0 ? <CountPill active={selectedAccount === account.id}>{account.unread}</CountPill> : null}
            </button>
          ))}
        </section>

        <section className="flex flex-col gap-1">
          <div className="mail-sidebar-section-label px-1.5 py-0.5 font-bold uppercase tracking-[0.12em] text-muted-foreground">Smart Filters</div>
          <SidebarAction icon={Clock3} label="Waiting on me" count={5} onClick={() => onSelectMailbox("inbox")} />
          <SidebarAction icon={Sparkles} label="Project Aurora" count={2} onClick={() => onSelectMailbox("inbox")} />
          <SidebarAction icon={MailCheck} label="Newsletters" count={12} onClick={() => onSelectMailbox("inbox")} />
        </section>
      </div>

    </div>
  );
}

function SidebarAction({
  icon: Icon,
  label,
  active,
  count,
  onClick,
}: {
  icon: React.ComponentType<React.SVGProps<SVGSVGElement>>;
  label: string;
  active?: boolean;
  count?: number;
  onClick: () => void;
}) {
  return (
    <button
      className={cn(
        "mail-sidebar-row flex h-6 items-center gap-1.5 rounded-md px-1.5 transition-colors hover:bg-primary/10",
        active && "bg-primary/10 font-semibold text-foreground"
      )}
      onClick={onClick}
      type="button"
    >
      <Icon className="size-3.5 text-primary" />
      <span className="min-w-0 flex-1 truncate text-left">{label}</span>
      {typeof count === "number" && count > 0 ? <CountPill active={active}>{count}</CountPill> : null}
    </button>
  );
}

function CountPill({ active, children }: { active?: boolean; children: React.ReactNode }) {
  return (
    <span
      className={cn(
        "mail-sidebar-count rounded-md px-1 py-0.5 font-bold",
        active ? "bg-primary text-primary-foreground" : "bg-primary/10 text-primary"
      )}
    >
      {children}
    </span>
  );
}

function ColumnResizeHandle({
  ariaLabel,
  onPointerDown,
}: {
  ariaLabel: string;
  onPointerDown: (event: React.PointerEvent<HTMLDivElement>) => void;
}) {
  return (
    <div
      aria-label={ariaLabel}
      className="group hidden w-1 shrink-0 cursor-col-resize items-stretch justify-center bg-border/55 transition-colors hover:bg-primary/30 md:flex"
      role="separator"
      tabIndex={0}
      onPointerDown={onPointerDown}
    >
      <div className="my-2 w-px rounded-full bg-transparent transition-colors group-hover:bg-primary/70" />
    </div>
  );
}

function ThreadColumn({
  query,
  selectedThreadId,
  theme,
  widthRem,
  threads,
  mobileReaderOpen,
  onOpenSidebar,
  onQueryChange,
  onSelectThread,
  onToggleStar,
}: {
  query: string;
  selectedThreadId: string;
  theme: "light" | "dark";
  widthRem: number;
  threads: MailThread[];
  mobileReaderOpen: boolean;
  onOpenSidebar: () => void;
  onQueryChange: (query: string) => void;
  onSelectThread: (id: string) => void;
  onToggleStar: (id: string) => void;
}) {
  const parentRef = React.useRef<HTMLDivElement>(null);
  const searchInputRef = React.useRef<HTMLInputElement>(null);

  React.useEffect(() => {
    function focusSearch(event: KeyboardEvent) {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
        event.preventDefault();
        searchInputRef.current?.focus();
      }
    }

    window.addEventListener("keydown", focusSearch);
    return () => window.removeEventListener("keydown", focusSearch);
  }, []);

  // eslint-disable-next-line react-hooks/incompatible-library -- TanStack Virtual intentionally exposes imperative measurement helpers.
  const virtualizer = useVirtualizer({
    count: threads.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 84,
    overscan: 6,
  });

  return (
    <div
      aria-label="Message list"
      className={cn(
        "w-full min-w-0 flex-col border-r md:flex md:w-[var(--thread-column-width)] md:shrink-0",
        mobileReaderOpen ? "hidden" : "flex"
      )}
      data-mobile-state={mobileReaderOpen ? "hidden" : "visible"}
      role="region"
      style={{ "--thread-column-width": `${widthRem}rem` } as React.CSSProperties}
    >
      <div className="border-b bg-card/90 px-2.5 py-2 backdrop-blur">
        <h1 className="sr-only md:hidden">Atelier Mail messages</h1>
        <div className="flex items-center gap-2">
          <Button aria-label="Open sidebar" className="md:hidden" size="icon" variant="ghost" onClick={onOpenSidebar}>
            <Menu />
          </Button>
          <div className="relative min-w-0 flex-1">
            <Search className="pointer-events-none absolute left-3.5 top-1/2 size-3 -translate-y-1/2 text-muted-foreground" />
            <Input
              ref={searchInputRef}
              aria-label="Search"
              className="mail-card-surface mail-search-input h-8 pl-10 pr-13"
              placeholder="Command-K to search"
              style={fieldSurfaceStyle(theme)}
              value={query}
              onChange={(event) => onQueryChange(event.target.value)}
            />
            <span className="mail-search-shortcut pointer-events-none absolute right-2 top-1/2 -translate-y-1/2 rounded-md border bg-background px-1.5 py-0.5 font-bold text-muted-foreground">
              Cmd K
            </span>
          </div>
          <Button
            aria-describedby="mail-preview-boundary"
            aria-label="Refresh unavailable in foundation preview"
            disabled
            size="icon"
            title="Provider refresh is not connected in this foundation preview"
          >
            <RefreshCw />
          </Button>
        </div>
        <div className="mt-1.5 flex items-center gap-2 text-[10px] font-semibold text-muted-foreground">
          <Keyboard />
          Press `J` / `K` to move later
        </div>
      </div>

      <div ref={parentRef} className="min-h-0 flex-1 overflow-y-auto bg-card">
        {threads.length === 0 ? (
          <div className="flex h-full flex-col items-center justify-center gap-3 p-8 text-center">
            <div className="grid size-12 place-items-center rounded-lg bg-secondary text-secondary-foreground">
              <Sparkles />
            </div>
            <div className="text-sm font-bold">Nothing matched that view</div>
            <p className="max-w-xs text-xs leading-5 text-muted-foreground">
              No local preview fixture matched this filter. Try all accounts or clear search.
            </p>
          </div>
        ) : (
          <div className="relative" style={{ height: virtualizer.getTotalSize() }}>
            {virtualizer.getVirtualItems().map((item) => {
              const thread = threads[item.index];
              return (
                <div
                  key={thread.id}
                  ref={virtualizer.measureElement}
                  data-index={item.index}
                  className="absolute left-0 top-0 w-full"
                  style={{ transform: `translateY(${item.start}px)` }}
                >
                  <ThreadRow
                    selected={selectedThreadId === thread.id}
                    theme={theme}
                    thread={thread}
                    onSelect={() => onSelectThread(thread.id)}
                    onToggleStar={() => onToggleStar(thread.id)}
                  />
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}

function ThreadRow({
  thread,
  selected,
  theme,
  onSelect,
  onToggleStar,
}: {
  thread: MailThread;
  selected: boolean;
  theme: "light" | "dark";
  onSelect: () => void;
  onToggleStar: () => void;
}) {
  return (
    <article
      className={cn(
        "mail-row-surface group border-b px-2.5 py-1.5 transition-colors",
        thread.unread && "mail-row-unread",
        selected && "mail-row-selected"
      )}
      style={threadRowStyle(thread, selected, theme)}
    >
      <button className="block w-full text-left" onClick={onSelect} type="button">
        <div className="flex items-center gap-2.5">
          <span
            aria-hidden="true"
            className={cn(
              "size-1.5 shrink-0 rounded-full border",
              thread.unread ? "border-primary bg-primary" : "border-muted-foreground/25 bg-transparent"
            )}
          />
          <ContactAvatar thread={thread} />
          <span className={cn("min-w-0 flex-1 truncate text-[0.8125rem] leading-4", thread.unread ? "font-bold" : "font-medium")}>{thread.from}</span>
          <time className="text-[11px] text-muted-foreground">{thread.time}</time>
        </div>
        <div className="mt-1 line-clamp-1 text-[0.8125rem] font-semibold leading-4">{thread.subject}</div>
        <p className="mt-0.5 line-clamp-1 text-[11px] leading-4 text-muted-foreground">{thread.snippet}</p>
      </button>
      <div className="mt-1.5 flex items-center justify-between gap-2">
        <div className="flex min-w-0 items-center gap-1">
          {thread.labels.slice(0, 2).map((label) => (
            <TagChip key={label} label={label} />
          ))}
        </div>
        <button
          aria-describedby="mail-preview-boundary"
          aria-label={thread.starred ? "Unstar locally in preview" : "Star locally in preview"}
          className={cn("rounded-md p-1 text-muted-foreground hover:bg-muted", thread.starred && "text-primary")}
          title="Changes only this browser fixture"
          onClick={onToggleStar}
          type="button"
        >
          <Star fill={thread.starred ? "currentColor" : "none"} />
        </button>
      </div>
    </article>
  );
}

function threadRowStyle(thread: MailThread, selected: boolean, theme: "light" | "dark"): React.CSSProperties {
  if (theme === "dark") {
    return {
      backgroundColor: selected ? "#28140e" : thread.unread ? "#1c100d" : "#0d0b0a",
      color: "#f6eee9",
    };
  }

  const backgroundColor = selected ? "#ffe4dc" : thread.unread ? "#ffebe5" : "#ffffff";

  return {
    backgroundColor,
    color: "#242120",
  };
}

function fieldSurfaceStyle(theme: "light" | "dark"): React.CSSProperties {
  return {
    backgroundColor: theme === "dark" ? "#0d0b0a" : "#ffffff",
    color: theme === "dark" ? "#f6eee9" : "#242120",
  };
}

function ContactAvatar({ thread }: { thread: MailThread }) {
  return (
    <span
      className={cn(
        "grid size-6 shrink-0 place-items-center rounded-full text-[9px] font-black shadow-[inset_0_0_0_1px_rgba(255,255,255,0.72)]",
        avatarToneClass[thread.avatarTone]
      )}
    >
      {thread.avatarInitials}
    </span>
  );
}

const avatarToneClass: Record<MailThread["avatarTone"], string> = {
  coral: "bg-[linear-gradient(135deg,#ff6a4a,#ffd0bd)] text-white",
  cyan: "bg-[linear-gradient(135deg,#18a6b8,#d6fbff)] text-slate-900",
  gold: "bg-[linear-gradient(135deg,#eab308,#fff2b6)] text-slate-900",
  ink: "bg-[linear-gradient(135deg,#111827,#d8dee9)] text-white",
};

function TagChip({ label }: { label: string }) {
  const style = tagStyles[label] ?? tagStyles.Default;
  const Icon = style.icon;

  return (
    <span className={cn("inline-flex h-[1.125rem] items-center gap-1 rounded-md border px-1.5 text-[9px] font-bold leading-none", style.className)}>
      <Icon className="size-3" />
      {label}
    </span>
  );
}

const tagStyles: Record<string, { icon: React.ComponentType<React.SVGProps<SVGSVGElement>>; className: string }> = {
  Architecture: {
    icon: Braces,
    className: "border-primary/25 bg-primary/10 text-primary",
  },
  PDS: {
    icon: Database,
    className: "border-accent/40 bg-accent/30 text-accent-foreground",
  },
  Gmail: {
    icon: Mail,
    className: "border-destructive/25 bg-destructive/10 text-destructive",
  },
  Sync: {
    icon: RefreshCw,
    className: "border-secondary/50 bg-secondary text-secondary-foreground",
  },
  JMAP: {
    icon: Tags,
    className: "border-border bg-muted text-muted-foreground",
  },
  IMAP: {
    icon: Archive,
    className: "border-accent/40 bg-accent/30 text-accent-foreground",
  },
  Fixture: {
    icon: FileText,
    className: "border-border bg-muted text-muted-foreground",
  },
  Default: {
    icon: Tags,
    className: "border-border bg-muted text-muted-foreground",
  },
};

function ReaderPane({
  thread,
  composeOpen,
  draft,
  showDebugChrome,
  theme,
  mobileOpen,
  onBack,
  onCloseCompose,
  onDraftChange,
  onReply,
  onToggleStar,
}: {
  thread?: MailThread;
  composeOpen: boolean;
  draft: ComposerDraft;
  showDebugChrome: boolean;
  theme: "light" | "dark";
  mobileOpen: boolean;
  onBack: () => void;
  onCloseCompose: () => void;
  onDraftChange: (draft: ComposerDraft) => void;
  onReply: () => void;
  onToggleStar: () => void;
}) {
  if (!thread) {
    return (
      <section
        aria-label="Message reader"
        className={cn(
          "min-w-0 flex-1 flex-col items-center justify-center gap-3 p-8 text-center md:flex",
          mobileOpen ? "flex" : "hidden"
        )}
        data-mobile-state={mobileOpen ? "visible" : "hidden"}
      >
        <Skeleton className="size-12" />
        <div className="text-sm font-bold">Select a thread</div>
      </section>
    );
  }

  return (
    <section
      aria-label="Message reader"
      className={cn(
        "min-h-0 min-w-0 flex-1 flex-col bg-background/70 md:flex",
        mobileOpen ? "flex" : "hidden"
      )}
      data-mobile-state={mobileOpen ? "visible" : "hidden"}
    >
      <header className="border-b bg-card/82 px-3.5 py-2.5 backdrop-blur">
        <div className="flex items-start justify-between gap-4">
          <div className="min-w-0">
            <div className="mb-2 flex items-center gap-2">
              {showDebugChrome ? <Badge variant="secondary">atelier://mail/thread/{thread.id}</Badge> : null}
              {thread.flagged ? <Badge variant="warning">Needs review</Badge> : null}
            </div>
            <h1 className="truncate text-lg font-black leading-6">{thread.subject}</h1>
            <p className="mt-0.5 truncate text-xs text-muted-foreground">
              {thread.from} &lt;{thread.email}&gt;
            </p>
          </div>
          <div className="flex items-center gap-1">
            <Button
              aria-label="Back to message list"
              className="md:hidden"
              size="icon"
              title="Back to message list"
              variant="ghost"
              onClick={onBack}
            >
              <ChevronLeft />
            </Button>
            <Button
              aria-describedby="mail-preview-boundary"
              aria-label="Archive unavailable in foundation preview"
              disabled
              size="icon"
              title="Provider archive is not connected in this foundation preview"
              variant="ghost"
            >
              <Archive />
            </Button>
            <Button
              aria-describedby="mail-preview-boundary"
              aria-label="Delete unavailable in foundation preview"
              disabled
              size="icon"
              title="Provider delete is not connected in this foundation preview"
              variant="ghost"
            >
              <Trash2 />
            </Button>
            <Button
              aria-describedby="mail-preview-boundary"
              aria-label={thread.starred ? "Unstar locally in preview" : "Star locally in preview"}
              className={cn(thread.starred && "text-primary")}
              size="icon"
              title="Changes only this browser fixture"
              variant="ghost"
              onClick={onToggleStar}
            >
              <Star fill={thread.starred ? "currentColor" : "none"} />
            </Button>
            <Button
              aria-describedby="mail-preview-boundary"
              aria-label="More provider actions unavailable in foundation preview"
              disabled
              size="icon"
              title="Provider actions are not connected in this foundation preview"
              variant="ghost"
            >
              <MoreHorizontal />
            </Button>
          </div>
        </div>
      </header>

      <div className="min-h-0 flex-1 overflow-y-auto px-3 py-3">
        <div className="mx-auto flex max-w-3xl flex-col">
          <div className="rounded-lg border bg-card p-3 shadow-sm">
            <div className="mb-2.5 flex items-center justify-between gap-3">
              <div className="flex items-center gap-3">
                <ContactAvatar thread={thread} />
                <div>
                  <div className="text-[0.8125rem] font-black leading-4">{thread.from}</div>
                  <div className="text-xs text-muted-foreground">to Atelier Ops</div>
                </div>
              </div>
              <div className="text-xs text-muted-foreground">{thread.time}</div>
            </div>
            <div className="flex flex-col gap-2.5 text-[0.8125rem] leading-5">
              {thread.body.map((paragraph) => (
                <p key={paragraph}>{paragraph}</p>
              ))}
            </div>
          </div>
        </div>
      </div>

      <footer className="border-t bg-card/86 p-3">
        {composeOpen ? (
          <div className="mail-composer mx-auto max-w-3xl rounded-lg border bg-background p-3 shadow-sm">
            <div className="mb-3 flex items-center justify-between gap-3">
              <div className="mail-composer-title flex items-center gap-2 font-black">
                <PenLine />
                Reply draft
              </div>
              <Button aria-label="Close compose" size="icon" variant="ghost" onClick={onCloseCompose}>
                <X />
              </Button>
            </div>
            <div className="flex flex-col gap-2">
              <Input
                className="mail-card-surface mail-composer-field"
                aria-label="To"
                style={fieldSurfaceStyle(theme)}
                value={draft.to}
                onChange={(event) => onDraftChange({ ...draft, to: event.target.value })}
              />
              <Input
                className="mail-card-surface mail-composer-field"
                aria-label="Subject"
                style={fieldSurfaceStyle(theme)}
                value={draft.subject}
                onChange={(event) => onDraftChange({ ...draft, subject: event.target.value })}
              />
              <div className="mail-markdown-composer" aria-label="Message editor" style={fieldSurfaceStyle(theme)}>
                <MarkdownBlockEditor
                  value={draft.body}
                  onChange={(body) => onDraftChange({ ...draft, body })}
                />
              </div>
              <div className="flex items-center justify-between gap-3">
                <div className="mail-composer-meta flex items-center gap-2 text-muted-foreground">
                  <Command />
                  Markdown source · MIME generation activates with the provider service
                </div>
                <Button
                  aria-describedby="mail-preview-boundary"
                  disabled
                  title="Provider delivery is not connected in this foundation preview"
                >
                  <Send data-icon="inline-start" />
                  Send unavailable
                </Button>
              </div>
            </div>
          </div>
        ) : (
          <div className="mx-auto flex max-w-3xl items-center justify-between gap-3 rounded-lg border bg-background px-3 py-2">
            <div className="flex items-center gap-2 text-sm text-muted-foreground">
              <MailCheck />
              Draft locally in this fixture; provider sync and delivery are not connected.
            </div>
            <div className="flex items-center gap-2">
              <Button title="Opens a local-only draft" variant="outline" onClick={onReply}>
                <PenLine data-icon="inline-start" />
                Draft reply locally
              </Button>
              <Button
                aria-describedby="mail-preview-boundary"
                disabled
                title="Provider snooze is not connected in this foundation preview"
                variant="secondary"
              >
                <Clock3 data-icon="inline-start" />
                Snooze unavailable
              </Button>
            </div>
          </div>
        )}
      </footer>
    </section>
  );
}
