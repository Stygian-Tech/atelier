import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, expect, test } from "bun:test";
import { MailWorkspace } from "@/components/mail/MailWorkspace";

beforeEach(() => {
  window.localStorage.clear();
  document.documentElement.className = "";
  delete document.documentElement.dataset.theme;
  Object.defineProperty(window, "matchMedia", {
    configurable: true,
    value: undefined,
  });
});

test("renders the signed-in mail workspace as the first screen", () => {
  render(<MailWorkspace appEnv="local" />);

  expect(screen.getByText("Atelier Mail")).toBeTruthy();
  expect(screen.getByText("Unified Inbox")).toBeTruthy();
  expect(screen.getByText("Opaque PDS references for linked mail threads")).toBeTruthy();
  expect(screen.getByText("Smart Filters")).toBeTruthy();
});

test("labels provider-backed content as a local preview", () => {
  render(<MailWorkspace appEnv="local" />);

  fireEvent.click(screen.getByRole("button", { name: "Close compose" }));

  expect(screen.getByText("Local preview fixture; provider sync and send are not connected yet.")).toBeTruthy();
});

test("starts from a saved dark mode preference", async () => {
  window.localStorage.setItem("atelier-mail-theme", "dark");

  render(<MailWorkspace appEnv="local" />);

  expect(screen.getByRole("button", { name: "Switch to light mode" })).toBeTruthy();
  await waitFor(() => expect(document.documentElement.classList.contains("dark")).toBe(true));
});

test("uses system dark mode as the first-run preference", () => {
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

  expect(screen.getByRole("button", { name: "Switch to light mode" })).toBeTruthy();
});

test("persists explicit theme toggles", async () => {
  render(<MailWorkspace appEnv="local" />);

  fireEvent.click(screen.getByRole("button", { name: "Switch to dark mode" }));

  await waitFor(() => expect(window.localStorage.getItem("atelier-mail-theme")).toBe("dark"));
  expect(document.documentElement.classList.contains("dark")).toBe(true);
});
