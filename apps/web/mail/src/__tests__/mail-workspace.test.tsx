import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, expect, test } from "bun:test";
import { act } from "react";
import { hydrateRoot } from "react-dom/client";
import { renderToString } from "react-dom/server";
import { MailWorkspace } from "@/components/mail/MailWorkspace";

beforeEach(() => {
  window.localStorage.clear();
  document.documentElement.className = "";
  delete document.documentElement.dataset.theme;
  Object.defineProperty(window, "innerWidth", { configurable: true, value: 1024 });
  Object.defineProperty(window, "matchMedia", {
    configurable: true,
    value: undefined,
  });
});

test("renders the signed-in mail workspace as the first screen", () => {
  render(<MailWorkspace appEnv="local" />);

  expect(screen.getByText("Atelier Mail")).toBeTruthy();
  expect(screen.getByText("Unified Inbox")).toBeTruthy();
  expect(screen.getAllByText("Opaque PDS references for linked mail threads").length).toBeGreaterThan(0);
  expect(screen.getByText("Smart Filters")).toBeTruthy();
});

test("keeps the fixture and provider-PDS boundary visible in production", () => {
  render(<MailWorkspace appEnv="prod" />);

  const boundary = screen.getByRole("note", { name: "Foundation preview — no provider actions" });

  expect(boundary.textContent).toContain("This inbox is fixture data");
  expect(boundary.textContent).toContain("Provider mail stays protected server-side");
  expect(boundary.textContent).toContain("public PDS records contain only opaque references");
});

test("starts from a saved dark mode preference", async () => {
  window.localStorage.setItem("atelier-mail-theme", "dark");

  render(<MailWorkspace appEnv="local" />);

  await waitFor(() => expect(screen.getByRole("button", { name: "Switch to light mode" })).toBeTruthy());
  await waitFor(() => expect(document.documentElement.classList.contains("dark")).toBe(true));
});

test("uses system dark mode as the first-run preference", async () => {
  Object.defineProperty(window, "matchMedia", {
    configurable: true,
    value: (query: string) =>
      ({
        matches: query === "(prefers-color-scheme: dark)",
        media: query,
        onchange: null,
        addEventListener() {},
        removeEventListener() {},
        addListener() {},
        removeListener() {},
        dispatchEvent() {
          return false;
        },
      }) satisfies MediaQueryList,
  });

  render(<MailWorkspace appEnv="local" />);

  await waitFor(() => expect(screen.getByRole("button", { name: "Switch to light mode" })).toBeTruthy());
});

test("persists explicit theme toggles", async () => {
  render(<MailWorkspace appEnv="local" />);

  fireEvent.click(screen.getByRole("button", { name: "Switch to dark mode" }));

  await waitFor(() => expect(window.localStorage.getItem("atelier-mail-theme")).toBe("dark"));
  expect(document.documentElement.classList.contains("dark")).toBe(true);
});

test("hydrates deterministic server markup before restoring browser preferences", async () => {
  const browserWindow = globalThis.window;
  Object.defineProperty(globalThis, "window", { configurable: true, value: undefined });
  const serverMarkup = renderToString(<MailWorkspace appEnv="prod" />);
  Object.defineProperty(globalThis, "window", { configurable: true, value: browserWindow });

  window.localStorage.setItem("atelier-mail-theme", "dark");
  window.localStorage.setItem("atelier-mail-sidebar-width-rem", "18");
  window.localStorage.setItem("atelier-mail-thread-width-rem", "31");

  const container = document.createElement("div");
  container.innerHTML = serverMarkup;
  document.body.appendChild(container);
  const recoverableErrors: unknown[] = [];
  let root: ReturnType<typeof hydrateRoot> | undefined;

  await act(async () => {
    root = hydrateRoot(container, <MailWorkspace appEnv="prod" />, {
      onRecoverableError: (error) => recoverableErrors.push(error),
    });
    await Promise.resolve();
  });

  await waitFor(() => expect(container.querySelector('[aria-label="Switch to light mode"]')).toBeTruthy());
  expect(recoverableErrors).toEqual([]);
  expect((container.querySelector('[aria-label="Message list"]') as HTMLElement).style.getPropertyValue("--thread-column-width")).toBe("31rem");

  await act(async () => root?.unmount());
  container.remove();
});

test("provides a 375px list to reader and composer path with a working back action", () => {
  Object.defineProperty(window, "innerWidth", { configurable: true, value: 375 });
  render(<MailWorkspace appEnv="prod" />);

  const messageList = screen.getByRole("region", { name: "Message list" });
  const messageReader = screen.getByRole("region", { name: "Message reader" });
  expect(messageList.dataset.mobileState).toBe("visible");
  expect(messageReader.dataset.mobileState).toBe("hidden");

  const firstThreadButton = screen
    .getAllByText("Opaque PDS references for linked mail threads")
    .map((element) => element.closest("button"))
    .find(Boolean);
  expect(firstThreadButton).toBeTruthy();
  fireEvent.click(firstThreadButton!);

  expect(messageList.dataset.mobileState).toBe("hidden");
  expect(messageReader.dataset.mobileState).toBe("visible");
  expect(screen.getByRole("heading", { name: "Opaque PDS references for linked mail threads", level: 1 })).toBeTruthy();
  expect(screen.getByLabelText("Message editor")).toBeTruthy();

  fireEvent.click(screen.getByRole("button", { name: "Back to message list" }));
  expect(messageList.dataset.mobileState).toBe("visible");
  expect(messageReader.dataset.mobileState).toBe("hidden");
});

test("labels local simulation and disables provider mutations", () => {
  render(<MailWorkspace appEnv="prod" />);

  const disabledActions = [
    "Refresh unavailable in foundation preview",
    "Archive unavailable in foundation preview",
    "Delete unavailable in foundation preview",
    "More provider actions unavailable in foundation preview",
    "Send unavailable",
  ];

  for (const name of disabledActions) {
    const action = screen.getByRole("button", { name });
    expect(action).toHaveProperty("disabled", true);
    expect(action.getAttribute("aria-describedby")).toBe("mail-preview-boundary");
  }

  fireEvent.click(screen.getAllByRole("button", { name: "Unstar locally in preview" })[0]);
  expect(screen.getByRole("status").textContent).toContain("only in this browser fixture");
  expect(screen.getByLabelText("Message editor")).toBeTruthy();

  fireEvent.click(screen.getByRole("button", { name: "Close compose" }));
  expect(screen.getByRole("button", { name: "Snooze unavailable" })).toHaveProperty("disabled", true);
  expect(screen.getByRole("button", { name: "Draft reply locally" })).toBeTruthy();
});
