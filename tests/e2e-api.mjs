import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";
import { PrismaClient } from "@prisma/client";

const base = process.env.E2E_BASE_URL ?? "http://127.0.0.1:3000";
const prisma = new PrismaClient();
const suffix = `${Date.now()}-${randomBytes(4).toString("hex")}`;
const users = [
  { name: "FinanceFlow E2E Owner", email: `financeflow-e2e-owner-${suffix}@example.test`, password: `E2e-${randomBytes(20).toString("base64url")}!` },
  { name: "FinanceFlow E2E Other", email: `financeflow-e2e-other-${suffix}@example.test`, password: `E2e-${randomBytes(20).toString("base64url")}!` },
];
let checks = 0;
function pass(label) { checks++; console.log(`PASS ${label}`); }
function expectStatus(response, code, label) {
  assert.equal(response.status, code, `${label}: expected HTTP ${code}, received ${response.status}: ${response.raw}`);
  pass(label);
}

class Client {
  cookies = new Map();
  csrfToken;
  async request(path, options = {}) {
    const headers = new Headers(options.headers ?? {});
    if (this.cookies.size) headers.set("cookie", [...this.cookies].map(([k, v]) => `${k}=${v}`).join("; "));
    const response = await fetch(new URL(path, base), { ...options, headers, redirect: "manual" });
    const setCookies = response.headers.getSetCookie?.() ?? [response.headers.get("set-cookie")].filter(Boolean);
    for (const value of setCookies) {
      const pair = value.split(";", 1)[0]; const i = pair.indexOf("=");
      if (i < 0) continue;
      const key = pair.slice(0, i), val = pair.slice(i + 1);
      if (!val || /Max-Age=0/i.test(value)) this.cookies.delete(key); else this.cookies.set(key, val);
    }
    const raw = await response.text();
    let data = null; try { data = raw ? JSON.parse(raw) : null; } catch { /* response is a file or page */ }
    return { status: response.status, headers: response.headers, data, raw };
  }
  async json(path, method = "GET", payload) {
    return this.request(path, { method, ...(payload === undefined ? {} : { headers: { "content-type": "application/json" }, body: JSON.stringify(payload) }) });
  }
  async signIn(user) {
    const csrf = await this.request("/api/auth/csrf");
    expectStatus(csrf, 200, "Auth CSRF token endpoint");
    this.csrfToken = csrf.data?.csrfToken;
    assert.ok(this.csrfToken, "Auth CSRF token is present");
    const body = new URLSearchParams({ csrfToken: this.csrfToken, email: user.email, password: user.password, callbackUrl: `${base}/overview`, json: "true" });
    const response = await this.request("/api/auth/callback/credentials", { method: "POST", headers: { "content-type": "application/x-www-form-urlencoded", "x-auth-return-redirect": "1" }, body });
    expectStatus(response, 200, `Credentials login (${user.name})`);
    const session = await this.request("/api/auth/session");
    assert.equal(session.data?.user?.email, user.email, "Session belongs to the signed-in test user");
    pass(`Session established (${user.name})`);
  }
}

const owner = new Client();
const other = new Client();
const api = (client, path, method, data) => client.json(path, method, data);

try {
  const health = await owner.request("/api/health"); expectStatus(health, 200, "Production health route"); assert.equal(health.data?.status, "ok");
  const publicLogin = await owner.request("/login"); expectStatus(publicLogin, 200, "Login UI route"); assert.match(publicLogin.raw, /FinanceFlow|Sign in/i);
  const unauthenticated = await owner.json("/api/transactions"); expectStatus(unauthenticated, 401, "Unauthenticated API access denied");

  for (const user of users) {
    const response = await api(owner, "/api/auth/register", "POST", user);
    expectStatus(response, 201, `Registration (${user.name})`);
    assert.ok(response.data?.data?.id);
  }
  await owner.signIn(users[0]);
  await other.signIn(users[1]);

  const pageRoutes = ["/overview", "/transactions", "/budgets", "/analytics", "/recurring", "/assistant", "/insights", "/receipts", "/savings", "/settings"];
  for (const route of pageRoutes) {
    const response = await owner.request(route);
    expectStatus(response, 200, `Authenticated page ${route}`);
    assert.match(response.raw, /FinanceFlow/);
  }

  let result = await api(owner, "/api/settings", "GET"); expectStatus(result, 200, "Load account settings"); assert.equal(result.data.data.currency, "INR");
  result = await api(owner, "/api/settings", "PATCH", { name: "FinanceFlow E2E Owner Updated", timezone: "Asia/Kolkata", preferences: { budgetAlerts: true, goalMilestones: true } }); expectStatus(result, 200, "Update profile, timezone, and notification preferences");

  result = await api(owner, "/api/categories", "GET"); expectStatus(result, 200, "Load owner categories");
  const food = result.data.data.find((x) => x.name === "Food" && x.type === "EXPENSE");
  const salary = result.data.data.find((x) => x.name === "Salary" && x.type === "INCOME");
  assert.ok(food && salary, "Registration creates default expense and income categories"); pass("Default categories provisioned");
  result = await api(other, "/api/categories", "GET"); expectStatus(result, 200, "Load second account categories");
  const foreignCategory = result.data.data.find((x) => x.name === "Food" && x.type === "EXPENSE");
  assert.ok(foreignCategory && foreignCategory.id !== food.id, "Each account has separate category ownership");
  const custom = await api(owner, "/api/categories", "POST", { name: `E2E dining ${suffix}`, type: "EXPENSE", color: "#123456" }); expectStatus(custom, 201, "Create custom category");
  expectStatus(await api(owner, "/api/categories", "POST", { name: `E2E dining ${suffix}`, type: "EXPENSE", color: "#123456" }), 409, "Reject duplicate category");
  expectStatus(await api(new Client(), "/api/categories", "POST", { name: `No session ${suffix}`, type: "EXPENSE" }), 401, "Unauthenticated category mutation denied");

  const now = new Date(); const date = now.toISOString().slice(0, 10); const month = now.getUTCMonth() + 1; const year = now.getUTCFullYear();
  const budget = await api(owner, "/api/budgets", "POST", { categoryId: food.id, amountLimit: "1000.00", month, year }); expectStatus(budget, 201, "Create monthly category budget");
  expectStatus(await api(owner, "/api/budgets", "POST", { categoryId: food.id, amountLimit: "1000.00", month, year }), 409, "Reject duplicate monthly budget");
  expectStatus(await api(other, `/api/budgets/${budget.data.data.id}`, "PATCH", { amountLimit: "1" }), 404, "Prevent cross-account budget edit");
  expectStatus(await api(other, "/api/budgets", "GET"), 200, "Load second account budgets");
  assert.equal((await api(other, "/api/budgets", "GET")).data.data.length, 0, "Budgets are isolated by user"); pass("Budget user isolation");

  const createTx = (amount, description, type = "EXPENSE", categoryId = food.id) => api(owner, "/api/transactions", "POST", { amount, description, type, categoryId, transactionDate: date, paymentMethod: "Test card", notes: "Synthetic E2E record" });
  let tx1 = await createTx("750.00", `=E2E test expense ${suffix}`); expectStatus(tx1, 201, "Create expense transaction");
  expectStatus(await api(owner, `/api/transactions/${tx1.data.data.id}`, "PATCH", { amount: "800.00" }), 200, "Edit transaction");
  const tx2 = await createTx("100.00", `E2E second expense ${suffix}`); expectStatus(tx2, 201, "Create second expense transaction");
  const tx3 = await createTx("100.00", `E2E third expense ${suffix}`); expectStatus(tx3, 201, "Create third expense transaction");
  const income = await createTx("5000.00", `E2E test income ${suffix}`, "INCOME", salary.id); expectStatus(income, 201, "Create income transaction");
  expectStatus(await api(owner, "/api/transactions", "POST", { amount: "-1", description: "invalid", type: "EXPENSE", categoryId: food.id, transactionDate: date }), 400, "Reject invalid transaction amount");
  expectStatus(await api(other, "/api/transactions", "POST", { amount: "1", description: "foreign category", type: "EXPENSE", categoryId: food.id, transactionDate: date }), 400, "Reject another user's category");
  const filtered = await owner.json(`/api/transactions?search=${encodeURIComponent(suffix)}&type=EXPENSE&page=1&pageSize=10&sort=amount_desc`);
  expectStatus(filtered, 200, "Filter and paginate transactions"); assert.equal(filtered.data.total, 3); assert.equal(filtered.data.data[0].amount, "800");
  expectStatus(await api(other, `/api/transactions/${tx1.data.data.id}`, "PATCH", { amount: "2" }), 404, "Prevent cross-account transaction edit");
  assert.equal((await other.json("/api/transactions")).data.total, 0); pass("Transaction data isolated by user");

  const budgetView = await owner.json(`/api/budgets?month=${month}&year=${year}`); expectStatus(budgetView, 200, "Read budget utilization");
  assert.equal(budgetView.data.data[0].spent.toString(), "1000"); assert.equal(budgetView.data.data[0].utilization.toString(), "100"); pass("Budget spend and utilization calculated from transactions");
  const notifications = await owner.json("/api/notifications"); expectStatus(notifications, 200, "Read budget notifications");
  assert.ok(notifications.data.data.some((x) => x.title.includes("75%"))); assert.ok(notifications.data.data.some((x) => x.title.includes("90%"))); assert.ok(notifications.data.data.some((x) => x.type === "BUDGET_EXCEEDED")); pass("75%, 90%, and exceeded budget notifications created");

  const from = new Date(Date.UTC(year, month - 1, 1)).toISOString().slice(0, 10); const to = new Date(Date.UTC(year, month, 1)).toISOString().slice(0, 10);
  const analytics = await owner.json(`/api/analytics?from=${from}&to=${to}`); expectStatus(analytics, 200, "Load financial analytics");
  assert.equal(analytics.data.data.totals.income.toString(), "5000"); assert.equal(analytics.data.data.totals.expenses.toString(), "1000"); pass("Analytics aggregate real database values");
  const csv = await owner.request(`/api/export/transactions?from=${from}&to=${to}`); expectStatus(csv, 200, "Download CSV report"); assert.match(csv.headers.get("content-type"), /text\/csv/); assert.match(csv.raw, /'=E2E test expense/); pass("CSV escaping prevents formula injection");
  const pdf = await owner.request(`/api/export/report?from=${from}&to=${to}`); expectStatus(pdf, 200, "Download PDF report"); assert.equal(pdf.headers.get("content-type"), "application/pdf"); assert.ok(pdf.raw.startsWith("%PDF-1.4")); pass("PDF report is generated");

  const goal = await api(owner, "/api/savings", "POST", { name: `E2E emergency ${suffix}`, targetAmount: "100.00", currentAmount: "80.00", targetDate: date }); expectStatus(goal, 201, "Create savings goal");
  assert.equal(goal.data.data.status, "ACTIVE");
  const goalNotices = await owner.json("/api/notifications"); assert.ok(goalNotices.data.data.some((x) => x.title.includes("75% saved"))); pass("Savings milestones notify at earned progress");
  const goalEdit = await api(owner, `/api/savings/${goal.data.data.id}`, "PATCH", { currentAmount: "100.00" }); expectStatus(goalEdit, 200, "Update savings progress"); assert.equal(goalEdit.data.data.status, "COMPLETED");
  expectStatus(await api(other, `/api/savings/${goal.data.data.id}`, "DELETE"), 404, "Prevent cross-account savings deletion");

  const yesterday = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - 1)).toISOString().slice(0, 10);
  const recurring = await api(owner, "/api/recurring", "POST", { categoryId: food.id, amount: "25.00", type: "EXPENSE", frequency: "DAILY", interval: 1, startDate: yesterday, endDate: yesterday, description: `E2E scheduled ${suffix}`, paymentMethod: "Test" }); expectStatus(recurring, 201, "Create recurring rule");
  expectStatus(await api(owner, `/api/recurring/${recurring.data.data.id}`, "PATCH", { isActive: false }), 200, "Pause recurring rule");
  expectStatus(await api(owner, `/api/recurring/${recurring.data.data.id}`, "PATCH", { isActive: true }), 200, "Resume recurring rule");
  const badCron = await owner.request("/api/jobs/recurring", { method: "POST" }); expectStatus(badCron, 401, "Protect recurring worker with secret");
  const job = await owner.request("/api/jobs/recurring", { method: "POST", headers: { authorization: `Bearer ${process.env.CRON_SECRET}` } }); expectStatus(job, 200, "Run authorized recurring job"); assert.equal(job.data.data.executed, 1);
  const again = await owner.request("/api/jobs/recurring", { method: "POST", headers: { authorization: `Bearer ${process.env.CRON_SECRET}` } }); expectStatus(again, 200, "Retry recurring job safely"); assert.equal(again.data.data.executed, 0); pass("Recurring execution is idempotent");
  expectStatus(await api(owner, "/api/recurring", "GET"), 200, "Read recurring rules and history");
  const rules = (await api(owner, "/api/recurring", "GET")).data.data; const completedRule = rules.find((x) => x.id === recurring.data.data.id); assert.equal(completedRule.occurrences.length, 1); assert.equal(completedRule.isActive, false); pass("Recurring execution history and end date honored");

  const prefs = await api(owner, "/api/notifications", "PATCH", { markAllRead: true }); expectStatus(prefs, 200, "Mark notifications read"); assert.equal((await api(owner, "/api/notifications", "GET")).data.unread, 0); pass("Notification read state updates");
  expectStatus(await api(owner, "/api/settings", "PATCH", { currency: "USD" }), 409, "Prevent silent currency changes after financial data exists");

  const validPng = Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jgWQAAAAASUVORK5CYII=", "base64");
  const form = new FormData(); form.set("file", new Blob([validPng], { type: "image/png" }), "e2e.png");
  const receipt = await owner.request("/api/receipts/scan", { method: "POST", body: form }); expectStatus(receipt, 503, "Receipt scan reports missing vision-provider configuration honestly"); assert.equal(receipt.data.error.code, "AI_NOT_CONFIGURED");
  const noAiInsight = await api(owner, "/api/insights", "POST", { type: "MONTHLY_REPORT" }); expectStatus(noAiInsight, 503, "Insights report missing AI provider honestly"); assert.equal(noAiInsight.data.error.code, "AI_NOT_CONFIGURED");
  const noAiAssistant = await api(owner, "/api/assistant", "POST", { message: "How much did I spend this month?" }); expectStatus(noAiAssistant, 503, "Assistant reports missing AI provider honestly"); assert.equal(noAiAssistant.data.error.code, "AI_NOT_CONFIGURED");

  expectStatus(await api(owner, `/api/transactions/${tx1.data.data.id}`, "DELETE"), 200, "Delete transaction through API");
  expectStatus(await api(owner, `/api/budgets/${budget.data.data.id}`, "DELETE"), 200, "Delete budget through API");
  expectStatus(await api(owner, `/api/savings/${goal.data.data.id}`, "DELETE"), 200, "Delete savings goal through API");
  expectStatus(await api(owner, `/api/recurring/${recurring.data.data.id}`, "DELETE"), 200, "Delete recurring rule through API");
  expectStatus(await api(owner, `/api/categories/${custom.data.data.id}`, "DELETE"), 200, "Delete custom category through API");

  const signedOut = await owner.request("/api/auth/signout", { method: "POST", headers: { "content-type": "application/x-www-form-urlencoded", "x-auth-return-redirect": "1" }, body: new URLSearchParams({ csrfToken: owner.csrfToken, callbackUrl: `${base}/login`, json: "true" }) }); expectStatus(signedOut, 200, "Sign out invalidates the session cookie");
  const sessionAfterSignOut = await owner.request("/api/auth/session"); assert.ok(!sessionAfterSignOut.data?.user?.email); pass("Signed-out session is anonymous");

  console.log(`\nE2E passed: ${checks} assertions across auth, UI routes, user isolation, transactions, categories, budgets, savings, recurring jobs, analytics, exports, notifications, receipt validation, and AI configuration boundaries.`);
} catch (error) {
  console.error("E2E FAILED", error);
  process.exitCode = 1;
} finally {
  try {
    const deleted = await prisma.user.deleteMany({ where: { email: { in: users.map((x) => x.email) } } });
    console.log(`Cleaned up ${deleted.count} disposable E2E account(s).`);
  } catch (error) { console.error("E2E cleanup failed; remove only accounts whose email begins with financeflow-e2e-", error); process.exitCode = 1; }
  await prisma.$disconnect();
}
