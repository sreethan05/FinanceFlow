import { createHash } from "node:crypto";
import bcrypt from "bcryptjs";
import { NextResponse } from "next/server";
import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { rateLimit } from "@/lib/rate-limit";
const schema = z.object({ token: z.string().min(20).max(200), password: z.string().min(10).max(128) });
export async function POST(request: Request) { if (!await rateLimit(request, "reset-password", 5, 900)) return NextResponse.json({ error: { code: "RATE_LIMITED", message: "Too many attempts. Try again later." } }, { status: 429 }); const body = schema.safeParse(await request.json().catch(() => null)); if (!body.success) return NextResponse.json({ error: { code: "INVALID_INPUT", message: "Use a valid reset link and a password of at least 10 characters." } }, { status: 400 }); const tokenHash = createHash("sha256").update(body.data.token).digest("hex"); const row = await prisma.passwordResetToken.findFirst({ where: { tokenHash, usedAt: null, expiresAt: { gt: new Date() } }, select: { id: true, userId: true } }); if (!row) return NextResponse.json({ error: { code: "INVALID_TOKEN", message: "This reset link is invalid or expired." } }, { status: 400 }); const passwordHash = await bcrypt.hash(body.data.password, 12); await prisma.$transaction([prisma.user.update({ where: { id: row.userId }, data: { passwordHash, sessionVersion: { increment: 1 } } }), prisma.passwordResetToken.update({ where: { id: row.id }, data: { usedAt: new Date() } })]); return NextResponse.json({ data: { reset: true } }); }
