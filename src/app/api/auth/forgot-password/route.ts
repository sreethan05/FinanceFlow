import { createHash, randomBytes } from "node:crypto";
import { NextResponse } from "next/server";
import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { mailConfigured, sendMail } from "@/services/mail.service";
import { rateLimit } from "@/lib/rate-limit";
const schema = z.object({ email: z.string().email().max(254) });
export async function POST(request: Request) { if (!await rateLimit(request, "forgot-password", 5, 3600)) return NextResponse.json({ error: { code: "RATE_LIMITED", message: "Too many attempts. Try again later." } }, { status: 429 }); const body = schema.safeParse(await request.json().catch(() => null)); if (body.success && mailConfigured()) { const user = await prisma.user.findUnique({ where: { email: body.data.email.toLowerCase() }, select: { id: true, email: true } }); if (user) { await prisma.passwordResetToken.updateMany({ where: { userId: user.id, usedAt: null }, data: { usedAt: new Date() } }); const token = randomBytes(32).toString("base64url"); await prisma.passwordResetToken.create({ data: { userId: user.id, tokenHash: createHash("sha256").update(token).digest("hex"), expiresAt: new Date(Date.now() + 30 * 60 * 1000) } }); await sendMail(user.email, "Reset your FinanceFlow password", `This link expires in 30 minutes: ${process.env.AUTH_URL ?? "http://localhost:3000"}/reset-password?token=${token}`); } } return NextResponse.json({ data: { requested: true } }); }
