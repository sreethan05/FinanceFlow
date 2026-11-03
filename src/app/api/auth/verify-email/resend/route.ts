import { createHash, randomBytes } from "node:crypto";
import { NextResponse } from "next/server";
import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { rateLimit } from "@/lib/rate-limit";
import { mailConfigured, sendMail } from "@/services/mail.service";
const schema = z.object({ email: z.string().email().max(254) });
export async function POST(request: Request) { if (!await rateLimit(request, "verify-resend", 5, 3600)) return NextResponse.json({ error: { code: "RATE_LIMITED", message: "Too many attempts. Try again later." } }, { status: 429 }); const body = schema.safeParse(await request.json().catch(() => null)); if (!body.success) return NextResponse.json({ data: { sent: true } }); const user = await prisma.user.findUnique({ where: { email: body.data.email.toLowerCase() }, select: { id: true, email: true, emailVerified: true } }); if (user && !user.emailVerified && mailConfigured()) { await prisma.emailVerificationToken.updateMany({ where: { userId: user.id, usedAt: null }, data: { usedAt: new Date() } }); const token = randomBytes(32).toString("base64url"); await prisma.emailVerificationToken.create({ data: { userId: user.id, tokenHash: createHash("sha256").update(token).digest("hex"), expiresAt: new Date(Date.now() + 86400000) } }); await sendMail(user.email, "Verify your FinanceFlow email", `Open this link to verify your email: ${process.env.AUTH_URL ?? "http://localhost:3000"}/api/auth/verify-email?token=${token}`); } return NextResponse.json({ data: { sent: true } }); }
