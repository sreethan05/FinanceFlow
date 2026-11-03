import { describe, expect, it } from "vitest";
import { nextOccurrence } from "../src/lib/recurrence";

describe("recurring schedule dates", () => {
  it("advances daily, weekly, and custom intervals as UTC calendar dates", () => {
    const start = new Date("2026-01-30T00:00:00.000Z");
    expect(nextOccurrence(start, "DAILY").toISOString()).toBe("2026-01-31T00:00:00.000Z");
    expect(nextOccurrence(start, "WEEKLY").toISOString()).toBe("2026-02-06T00:00:00.000Z");
    expect(nextOccurrence(start, "CUSTOM", 10).toISOString()).toBe("2026-02-09T00:00:00.000Z");
  });
  it("clamps monthly schedules to the final day of shorter months", () => {
    expect(nextOccurrence(new Date("2026-01-31T00:00:00Z"), "MONTHLY").toISOString()).toBe("2026-02-28T00:00:00.000Z");
  });
  it("handles leap day schedules without rolling into March", () => {
    expect(nextOccurrence(new Date("2024-02-29T00:00:00Z"), "YEARLY").toISOString()).toBe("2025-02-28T00:00:00.000Z");
  });
});
