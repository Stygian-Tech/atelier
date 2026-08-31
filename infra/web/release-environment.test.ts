import { describe, expect, test } from "bun:test";

import {
  assertProductOrigins,
  getAtelierEnvironment,
  isIndexableEnvironment,
  resolveAtelierOrigin,
} from "./release-environment.mjs";

const developmentProductOrigins = {
  ATELIER_ENV: "development",
  NEXT_PUBLIC_HOME_URL: "https://home.testing.atelier.diy",
  NEXT_PUBLIC_NOTES_URL: "https://notes.testing.atelier.diy",
  NEXT_PUBLIC_MAIL_URL: "https://mail.testing.atelier.diy",
  NEXT_PUBLIC_CALENDAR_URL: "https://calendar.testing.atelier.diy",
  NEXT_PUBLIC_TASKS_URL: "https://tasks.testing.atelier.diy",
};

describe("web release environment", () => {
  test("keeps explicit localhost defaults for local development", () => {
    expect(getAtelierEnvironment("")).toBe("local");
    expect(
      resolveAtelierOrigin("ATELIER_MARKETING_ORIGIN", "http://localhost:4321", {
        ATELIER_ENV: "local",
      }),
    ).toBe("http://localhost:4321");
    expect(isIndexableEnvironment({ ATELIER_ENV: "local" })).toBe(false);
  });

  test("requires every product origin in a deployed environment", () => {
    expect(() => assertProductOrigins({ ATELIER_ENV: "development" })).toThrow(
      "NEXT_PUBLIC_HOME_URL is required",
    );
    expect(() => assertProductOrigins(developmentProductOrigins)).not.toThrow();
  });

  test("rejects localhost, cross-environment hosts, paths, and unknown environments", () => {
    expect(() =>
      resolveAtelierOrigin("ATELIER_MARKETING_ORIGIN", "http://localhost:4321", {
        ATELIER_ENV: "production",
        ATELIER_MARKETING_ORIGIN: "http://localhost:4321",
      }),
    ).toThrow("must be https://atelier.diy");
    expect(() =>
      resolveAtelierOrigin("ATELIER_MARKETING_ORIGIN", "http://localhost:4321", {
        ATELIER_ENV: "production",
        ATELIER_MARKETING_ORIGIN: "https://testing.atelier.diy",
      }),
    ).toThrow("must be https://atelier.diy");
    expect(() =>
      resolveAtelierOrigin("ATELIER_MARKETING_ORIGIN", "http://localhost:4321", {
        ATELIER_MARKETING_ORIGIN: "https://atelier.diy/path",
      }),
    ).toThrow("only an absolute HTTP(S) origin");
    expect(() => getAtelierEnvironment("staging")).toThrow("ATELIER_ENV must be");
  });

  test("only Production is indexable", () => {
    expect(isIndexableEnvironment({ ATELIER_ENV: "development" })).toBe(false);
    expect(isIndexableEnvironment({ ATELIER_ENV: "production" })).toBe(true);
  });
});
