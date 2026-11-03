import { NextResponse } from "next/server";
import bcrypt from "bcryptjs";
import { createHash, randomBytes } from "node:crypto";
import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { mailConfigured, sendMail } from "@/services/mail.service";
import { rateLimit } from "@/lib/rate-limit";

const schema = z.object({ name: z.string().trim().min(1).max(80), email: z.string().email().max(254), password: z.string().min(10).max(128) });
const defaults = [
  ...["Salary", "Freelancing", "Investments", "Other income"].map((name) => ({ name, type: "INCOME" as const, color: "#16856b" })),
  ...["Food", "Shopping", "Transport", "Rent", "Utilities", "Healthcare", "Education", "Entertainment", "Subscriptions", "Other expenses"].map((name) => ({ name, type: "EXPENSE" as const, color: "#e17a62" })),
];
export async function POST(request: Request) {
  if (!await rateLimit(request, "register", 5, 3600)) return NextResponse.json({ error: { code: "RATE_LIMITED", message: "Too many attempts. Try again later." } }, { status: 429 });
  const parsed = schema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: { code: "INVALID_INPUT", message: "Check your details and try again." } }, { status: 400 });
  const email = parsed.data.email.toLowerCase();
  if (await prisma.user.findUnique({ where: { email }, select: { id: true } })) return NextResponse.json({ error: { code: "EMAIL_IN_USE", message: "An account with this email already exists." } }, { status: 409 });
  const user = await prisma.user.create({ data: { name: parsed.data.name, email, passwordHash: await bcrypt.hash(parsed.data.password, 12), categories: { create: defaults.map((item) => ({ ...item, isDefault: true })) }, notificationPreference: { create: {} } }, select: { id: true } });
  if (mailConfigured()) { const token = randomBytes(32).toString("base64url"); await prisma.emailVerificationToken.create({ data: { userId: user.id, tokenHash: createHash("sha256").update(token).digest("hex"), expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000) } }); await sendMail(email, "Verify your FinanceFlow email", `Open this link to verify your email: ${process.env.AUTH_URL ?? "http://localhost:3000"}/api/auth/verify-email?token=${token}`); }
  return NextResponse.json({ data: { id: user.id } }, { status: 201 });
}
