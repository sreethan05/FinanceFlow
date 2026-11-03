import { NextResponse } from "next/server";
import { z } from "zod";
import { auth } from "@/lib/auth";
import { prisma } from "@/lib/prisma";

const schema = z.object({ name: z.string().trim().min(1).max(50), type: z.enum(["INCOME", "EXPENSE"]), color: z.string().regex(/^#[\da-fA-F]{6}$/).default("#64748b") });
export async function GET() {
  const session = await auth(); if (!session?.user?.id) return NextResponse.json({ error: { code: "UNAUTHORIZED", message: "Sign in to continue." } }, { status: 401 });
  const data = await prisma.category.findMany({ where: { userId: session.user.id }, orderBy: [{ type: "asc" }, { name: "asc" }] });
  return NextResponse.json({ data });
}
export async function POST(request: Request) {
  const session = await auth(); if (!session?.user?.id) return NextResponse.json({ error: { code: "UNAUTHORIZED", message: "Sign in to continue." } }, { status: 401 });
  const parsed = schema.safeParse(await request.json().catch(() => null)); if (!parsed.success) return NextResponse.json({ error: { code: "INVALID_INPUT", message: "Enter a category name and type." } }, { status: 400 });
  try { const data = await prisma.category.create({ data: { ...parsed.data, userId: session.user.id } }); return NextResponse.json({ data }, { status: 201 }); }
  catch { return NextResponse.json({ error: { code: "DUPLICATE_CATEGORY", message: "That category already exists." } }, { status: 409 }); }
}
