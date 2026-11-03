import { createHash } from "node:crypto";
import { NextResponse } from "next/server";
import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { rateLimit } from "@/lib/rate-limit";
export async function GET(request: Request) { if (!await rateLimit(request, "verify-email", 15, 3600)) return NextResponse.redirect(new URL("/login?verified=0", request.url)); const token = z.string().min(20).safeParse(new URL(request.url).searchParams.get("token")); if (!token.success) return NextResponse.redirect(new URL("/login?verified=0", request.url)); const tokenHash = createHash("sha256").update(token.data).digest("hex"); const row = await prisma.emailVerificationToken.findFirst({ where: { tokenHash, usedAt: null, expiresAt: { gt: new Date() } }, select: { id: true, userId: true } }); if (!row) return NextResponse.redirect(new URL("/login?verified=0", request.url)); await prisma.$transaction([prisma.user.update({ where: { id: row.userId }, data: { emailVerified: new Date() } }), prisma.emailVerificationToken.update({ where: { id: row.id }, data: { usedAt: new Date() } })]); return NextResponse.redirect(new URL("/login?verified=1", request.url)); }
