import { test, expect, request as playwrightRequest } from "@playwright/test";
import { PrismaClient } from "@prisma/client";
import { randomBytes } from "node:crypto";

const baseURL = "http://127.0.0.1:3001";
const email = `financeflow-browser-${Date.now()}-${randomBytes(4).toString("hex")}@example.test`;
const password = `Browser-E2E-${randomBytes(20).toString("base64url")}!`;
const prisma = new PrismaClient();

 test.beforeAll(async () => {
  const api = await playwrightRequest.newContext({ baseURL });
  const response = await api.post("/api/auth/register", { data: { name: "FinanceFlow Browser Test", email, password } });
  expect(response.status(), await response.text()).toBe(201);
  await api.dispose();
});

test.afterAll(async () => {
  await prisma.user.deleteMany({ where: { email } });
  await prisma.$disconnect();
});

test("sign in, add, edit, search, and delete a transaction through the UI", async ({ page }) => {
  const description = `Browser E2E ${randomBytes(4).toString("hex")}`;
  await page.goto("/login");
  await page.waitForLoadState("networkidle");
  await page.getByLabel("Email address").fill(email);
  await page.getByLabel("Password").fill(password);
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page).toHaveURL(/\/overview$/, { timeout: 15_000 });
  await expect(page.getByRole("heading", { name: /Good (morning|afternoon|evening), FinanceFlow/ })).toBeVisible();

  await page.getByRole("link", { name: "Transactions", exact: true }).click();
  await expect(page.getByRole("heading", { name: "Transactions" })).toBeVisible();
  await page.getByRole("button", { name: "Add transaction" }).click();
  await page.getByLabel("Type").selectOption("EXPENSE");
  await page.getByLabel("Amount").fill("53.20");
  await page.getByLabel("Description").fill(description);
  await page.getByLabel("Category").selectOption({ label: "Food" });
  await page.getByLabel("Date", { exact: true }).fill(new Date().toISOString().slice(0, 10));
  await page.getByLabel("Payment method").fill("Browser test card");
  await page.getByLabel("Notes").fill("Disposable browser test entry");
  await page.getByRole("button", { name: "Save transaction" }).click();
  await expect(page.getByRole("cell", { name: description })).toBeVisible();

  await page.getByTitle("Edit transaction").click();
  await page.getByLabel("Amount").fill("63.20");
  await page.getByRole("button", { name: "Save changes" }).click();
  await expect(page.getByText(/₹63\.2/)).toBeVisible();

  await page.getByPlaceholder("Search transactions…").fill(description);
  await expect(page.getByRole("cell", { name: description })).toBeVisible();
  page.once("dialog", (dialog) => dialog.accept());
  await page.getByTitle("Delete transaction").click();
  await expect(page.getByText("No transactions found")).toBeVisible();
});
