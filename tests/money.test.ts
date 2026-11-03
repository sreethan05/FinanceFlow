import { describe, expect, it } from "vitest";
import { formatMoney } from "../src/lib/format-money";
import { transactionSchema } from "../src/lib/validations/transaction";

describe("money validation and display", () => {
  it("accepts decimal strings without converting them to floating point", () => {
    expect(transactionSchema.safeParse({ amount: "0.10", type: "EXPENSE", categoryId: "cat", description: "Tea", transactionDate: "2026-11-03" }).success).toBe(true);
    expect(transactionSchema.safeParse({ amount: "1e3", type: "EXPENSE", categoryId: "cat", description: "Tea", transactionDate: "2026-11-03" }).success).toBe(false);
  });
  it("rejects zero, negatives, and excessive precision", () => {
    for (const amount of ["0", "-1", "1.12345"]) expect(transactionSchema.safeParse({ amount, type: "EXPENSE", categoryId: "cat", description: "Tea", transactionDate: "2026-11-03" }).success).toBe(false);
  });
  it("formats large values with Indian grouping and currency symbols accurately", () => {
    expect(formatMoney("1234567890123.40", "INR")).toContain("12,34,56,78,90,123.4");
    expect(formatMoney("1200.50", "USD")).toContain("1,200.5");
  });
});
