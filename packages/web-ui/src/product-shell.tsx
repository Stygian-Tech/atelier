import {
  CalendarDays,
  CheckSquare2,
  CircleHelp,
  FileText,
  Home,
  Inbox,
  Mail,
  Search,
  ShieldAlert,
} from "lucide-react";
import type { ReactNode } from "react";

export type ProductKey = "home" | "notes" | "mail" | "calendar" | "tasks";

const products: Array<{ key: ProductKey; label: string; href: string }> = [
  { key: "home", label: "Home", href: process.env.NEXT_PUBLIC_HOME_URL ?? "http://localhost:3000" },
  { key: "notes", label: "Notes", href: process.env.NEXT_PUBLIC_NOTES_URL ?? "http://localhost:3001" },
  { key: "mail", label: "Mail", href: process.env.NEXT_PUBLIC_MAIL_URL ?? "http://localhost:3002" },
  { key: "calendar", label: "Calendar", href: process.env.NEXT_PUBLIC_CALENDAR_URL ?? "http://localhost:3003" },
  { key: "tasks", label: "Tasks", href: process.env.NEXT_PUBLIC_TASKS_URL ?? "http://localhost:3004" },
];

const productIcons = {
  home: Home,
  notes: FileText,
  mail: Mail,
  calendar: CalendarDays,
  tasks: CheckSquare2,
} as const;

export function AtelierHeader({ current }: { current: ProductKey }) {
  return (
    <header className="atelier-topbar">
      <a className="atelier-brand" href={products[0].href} aria-label="Atelier Home">
        <span className="atelier-brand-mark" aria-hidden="true">A</span>
        <span>{current === "home" ? "Atelier" : `Atelier ${products.find((product) => product.key === current)?.label}`}</span>
      </a>
      <nav className="atelier-product-nav" aria-label="Atelier products">
        {products.map((product) => (
          <a key={product.key} href={product.href} aria-current={current === product.key ? "page" : undefined}>
            {product.label}
          </a>
        ))}
      </nav>
      <button className="atelier-command" type="button" aria-label="Open global search">
        <Search size={15} aria-hidden="true" />
        Search Atelier
        <kbd>⌘ K</kbd>
      </button>
      <button className="atelier-avatar" type="button" aria-label="Open account menu">SC</button>
    </header>
  );
}

export function PublicPdsNotice({ compact = false }: { compact?: boolean }) {
  return (
    <aside className="atelier-public-notice" role="note" aria-label="Public PDS disclosure">
      <ShieldAlert size={18} aria-hidden="true" />
      <span>
        <strong>{compact ? "Public PDS" : "Stored as a readable public PDS record"}</strong>
        {compact
          ? "Anyone who finds the record can read it until Permissioned Spaces is enabled."
          : "This first-party Atelier content is not private yet. Discovery is limited to your workspace, but standard ATProto repositories are public."}
      </span>
    </aside>
  );
}

export function FoundationPreviewNotice({ children }: { children: ReactNode }) {
  return (
    <aside className="atelier-public-notice" role="status" data-foundation-preview>
      <CircleHelp size={18} aria-hidden="true" />
      <span>
        <strong>Foundation preview</strong>
        {children}
      </span>
    </aside>
  );
}

export function ProductShell({
  current,
  sidebar,
  children,
}: {
  current: ProductKey;
  sidebar: ReactNode;
  children: ReactNode;
}) {
  const Icon = productIcons[current];
  return (
    <div className="atelier-app">
      <AtelierHeader current={current} />
      <div className="atelier-page">
        <div className="atelier-workspace">
          <aside className="atelier-sidebar">
            <div className="atelier-chip atelier-chip-coral"><Icon size={13} aria-hidden="true" /> {products.find((product) => product.key === current)?.label}</div>
            {sidebar}
            <div className="atelier-sidebar-label">Workspace</div>
            <button type="button" className="atelier-sidebar-link"><Inbox size={15} aria-hidden="true" /> Shared inbox</button>
            <button type="button" className="atelier-sidebar-link"><CircleHelp size={15} aria-hidden="true" /> Help & shortcuts</button>
          </aside>
          <main className="atelier-main-panel">{children}</main>
        </div>
      </div>
    </div>
  );
}

export function PageHeading({ eyebrow, title, description, action }: { eyebrow: string; title: string; description: string; action?: ReactNode }) {
  return (
    <div className="atelier-page-heading">
      <div>
        <p className="atelier-eyebrow">{eyebrow}</p>
        <h1>{title}</h1>
        <p>{description}</p>
      </div>
      {action}
    </div>
  );
}
