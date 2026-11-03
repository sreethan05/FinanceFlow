# FinanceFlow

FinanceFlow includes a Flutter mobile client in [`flutter_app/`](./flutter_app/README.md) and a PostgreSQL-backed Next.js API/server in this repository. The mobile app provides account access, a live cash-flow overview, transaction creation and history, budget progress, and savings goals. The server also includes recurring payments, exports, receipt extraction, AI insights, and a grounded financial assistant.

## Features

- **Accounts:** email/password registration and login, optional Google OAuth, optional email verification, password reset, session invalidation after password reset, profile and notification preferences.
- **Transactions:** income and expenses with server-side pagination, category/date/type/search/sort filters, edit/delete, custom categories, notes, payment methods, receipt association, and formula-safe CSV exports.
- **Overview and analytics:** live database totals and chart series, Indian locale display, account currency preference, monthly/yearly PDF reports, category breakdown, cash flow, and period selection.
- **Budgets:** category/month budgets with duplicate prevention, utilization, and idempotent 75%, 90%, and exceeded alerts.
- **Savings:** goal tracking, contribution editing, progress, and milestone notifications.
- **Recurring:** daily/weekly/monthly/yearly/custom schedules, pause/resume/edit, execution history, and an authenticated idempotent scheduled job.
- **AI:** configurable OpenAI-compatible provider; calculated aggregates remain deterministic, prompts receive minimized summaries, response structures are validated, insight results are cached, and missing credentials produce an explicit configuration error.
- **Receipts:** JPG/PNG/WebP validation, private filesystem storage, hash-based duplicate detection, vision extraction into a reviewable draft, and explicit user confirmation before saving a transaction.
- **Notifications:** budget, unusual spending, recurring, goal milestone, and monthly report events, with read state and preferences.
- **Security:** server-side ownership checks, Zod validation, bcrypt password hashing, single-use hashed mail tokens, sensitive endpoint rate limits, CSP and security headers, and decimal database values.
- **Theme:** light/dark toggle persisted in the browser, with OS preference as the initial default.

The architecture, ER diagram, schema decisions, endpoint catalog, AI boundary, and security model are described in [ARCHITECTURE.md](./ARCHITECTURE.md). The canonical database schema is [prisma/schema.prisma](./prisma/schema.prisma).

## Requirements

- Node.js 20.9 or newer
- PostgreSQL 15 or newer
- A mail provider for verification/reset email (optional for local development)
- An OpenAI-compatible API for AI insights, assistant answers, and receipt vision (optional; those features report configuration errors when absent)
- Upstash Redis for distributed production rate limiting
- Persistent private storage for receipt files; mount a persistent volume or set `RECEIPT_STORAGE_DIR`

## Local setup

For the Flutter application, follow [`flutter_app/README.md`](./flutter_app/README.md). Run the API setup below first so the mobile client has a backend to connect to.

1. Copy `.env.example` to `.env` and configure `DATABASE_URL` and a random `AUTH_SECRET`.
2. Install dependencies: `npm install`.
3. Generate Prisma Client: `npm run db:generate`.
4. Apply the migration: `npm run db:migrate`.
5. Start the app: `npm run dev` and register at `/register`.

Generate an auth secret with `node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"`. The seed script does not create demo financial history. It can ensure standard categories and preferences for an already registered user by setting `SEED_EMAIL` and running `npm run db:seed`.

## Configuration

| Variable | Required | Purpose |
| --- | --- | --- |
| `DATABASE_URL` | Yes | PostgreSQL connection string |
| `AUTH_SECRET`, `NEXTAUTH_SECRET` | Yes | Use the same random value for the app and NextAuth v4 |
| `AUTH_URL`, `NEXTAUTH_URL` | Yes in production | Same canonical HTTPS app URL; `AUTH_URL` is also used in email links |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | Optional | Enables Google OAuth; callback is `${NEXTAUTH_URL}/api/auth/callback/google` |
| `REQUIRE_EMAIL_VERIFICATION` | Optional | Set `true` to prevent credential login until verified |
| `MAIL_API_URL`, `MAIL_API_KEY`, `MAIL_FROM` | Optional | Resend-compatible email API for verification and password reset |
| `AI_BASE_URL`, `AI_API_KEY`, `AI_MODEL`, `AI_VISION_MODEL` | Optional | Server-side OpenAI-compatible chat and vision endpoints |
| `UPSTASH_REDIS_REST_URL`, `UPSTASH_REDIS_REST_TOKEN` | Production | Distributed rate limiter; production sensitive routes fail closed if missing |
| `CRON_SECRET` | Production | Bearer secret for `/api/jobs/recurring` |
| `RECEIPT_STORAGE_DIR` | Optional | Private persistent directory; defaults to `.private-receipts` |

Do not commit `.env`. Use a secret manager in hosted environments. Do not expose provider keys with `NEXT_PUBLIC_` prefixes.

## Background recurring job

Call `POST /api/jobs/recurring` with `Authorization: Bearer $CRON_SECRET` from a scheduler every few minutes. The database stores a unique row for each rule and scheduled occurrence, so retries do not create duplicate transactions. Keep the job endpoint inaccessible to public callers without the secret.

## Tests and production checks

- `npm test` runs unit tests for money validation/formatting and recurrence date boundaries.
- `npm run test:e2e` exercises the running local app and real PostgreSQL using disposable accounts, then deletes only those test accounts. Start `npm run dev` first; it covers registration/login, signed-in pages, owner isolation, finance workflows, recurring retries, exports, notifications, and explicit missing-provider responses.
- `npm run test:browser` starts an isolated local dev server on port 3001 and uses installed Google Chrome to sign in, create/edit/search/delete a transaction through the UI, then removes its disposable account.
- `npm run lint` runs ESLint.
- `npx tsc --noEmit` checks TypeScript.
- `npm run build` creates the production build.
- `npm audit --omit=dev` checks production dependency advisories.

Authenticated end-to-end checks require a running PostgreSQL instance and configured `.env`. AI, mail, Google OAuth, Redis, and cron behavior require their respective provider configuration. The current receipt adapter stores private files on local persistent disk; for horizontally scaled or ephemeral deployments, connect a private object-storage adapter before using multiple app instances. Configure automated encrypted database backups and test restores before storing real financial records in a production environment.

## API overview

`GET /api/health` provides a no-store database readiness check without revealing connection details. Authenticated REST routes cover `/api/transactions`, `/api/categories`, `/api/budgets`, `/api/analytics`, `/api/recurring`, `/api/savings`, `/api/receipts`, `/api/insights`, `/api/assistant`, `/api/notifications`, `/api/settings`, `/api/export`, and `/api/jobs/recurring`. Registration, OAuth callbacks, email verification, and password recovery routes are under `/api/auth`. See [ARCHITECTURE.md](./ARCHITECTURE.md#5-api-specification) for the resource-by-resource contract.
