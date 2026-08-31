import { describe, expect, test } from "bun:test";

import {
  isIndexableProductOrigin,
  parseAtelierEnvironment,
  resolveProductOrigins,
} from "../src/public-origins";

describe("product web origins", () => {
  test("allows explicit localhost origins only for the local environment", () => {
    expect(resolveProductOrigins({
      ATELIER_ENV: "local",
      NEXT_PUBLIC_HOME_URL: "http://localhost:3000",
      NEXT_PUBLIC_NOTES_URL: "http://localhost:3001",
      NEXT_PUBLIC_MAIL_URL: "http://localhost:3002",
      NEXT_PUBLIC_CALENDAR_URL: "http://localhost:3003",
      NEXT_PUBLIC_TASKS_URL: "http://localhost:3004",
    })).toEqual({
      home: "http://localhost:3000",
      notes: "http://localhost:3001",
      mail: "http://localhost:3002",
      calendar: "http://localhost:3003",
      tasks: "http://localhost:3004",
    });
  });

  test("accepts the complete Development origin set", () => {
    expect(resolveProductOrigins({
      ATELIER_ENV: "development",
      NEXT_PUBLIC_HOME_URL: "https://home.testing.atelier.diy",
      NEXT_PUBLIC_NOTES_URL: "https://notes.testing.atelier.diy",
      NEXT_PUBLIC_MAIL_URL: "https://mail.testing.atelier.diy",
      NEXT_PUBLIC_CALENDAR_URL: "https://calendar.testing.atelier.diy",
      NEXT_PUBLIC_TASKS_URL: "https://tasks.testing.atelier.diy",
    }).home).toBe("https://home.testing.atelier.diy");
  });

  test("fails closed on missing and cross-environment deployed origins", () => {
    expect(() => resolveProductOrigins({ ATELIER_ENV: "production" })).toThrow(
      "NEXT_PUBLIC_HOME_URL is required",
    );
    expect(() => resolveProductOrigins({
      ATELIER_ENV: "production",
      NEXT_PUBLIC_HOME_URL: "https://home.testing.atelier.diy",
      NEXT_PUBLIC_NOTES_URL: "https://notes.atelier.diy",
      NEXT_PUBLIC_MAIL_URL: "https://mail.atelier.diy",
      NEXT_PUBLIC_CALENDAR_URL: "https://calendar.atelier.diy",
      NEXT_PUBLIC_TASKS_URL: "https://tasks.atelier.diy",
    })).toThrow("NEXT_PUBLIC_HOME_URL must be https://home.atelier.diy");
  });

  test("rejects unknown release environments", () => {
    expect(() => parseAtelierEnvironment("staging")).toThrow("Unsupported ATELIER_ENV");
  });

  test("indexes only canonical Production product hosts", () => {
    expect(isIndexableProductOrigin("https://home.atelier.diy")).toBe(true);
    expect(isIndexableProductOrigin("https://home.testing.atelier.diy")).toBe(false);
    expect(isIndexableProductOrigin("http://localhost:3000")).toBe(false);
  });
});
