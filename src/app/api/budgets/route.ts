import { NextResponse } from "next/server";
import { z } from "zod";
import { userIdOrResponse, amountSchema, errorResponse } from "@/lib/api";
import { prisma } from "@/lib/prisma";
import { budgetSnapshot } from "@/services/budget.service";

const schema = z.object({ categoryId: z.string().min(1), amountLimit: amountSchema, month: z.coerce.number().int().min(1).max(12), year: z.coerce.number().int().min(2000).max(2200) });
export async function GET(request: Request) {
  const { userId, response } = await userIdOrResponse(); if (response) return response;
  const url = new URL(request.url), now = new Date(); const month = Number(url.searchParams.get("month")) || now.getMonth() + 1; const year = Number(url.searchParams.get("year")) || now.getFullYear();
  return NextResponse.json({ data: await budgetSnapshot(userId!, month, year) });
}
export async function POST(request: Request) {
  const { userId, response } = await userIdOrResponse(); if (response) return response;
  const body = schema.safeParse(await request.json().catch(() => null)); if (!body.success) return errorResponse("INVALID_INPUT", "Choose a category, month, year, and valid budget amount.");
  const category = await prisma.category.findFirst({ where: { id: body.data.categoryId, userId: userId!, type: "EXPENSE" }, select: { id: true } }); if (!category) return errorResponse("INVALID_CATEGORY", "Choose one of your expense categories.");
  try { const data = await prisma.budget.create({ data: { ...body.data, userId: userId! } }); return NextResponse.json({ data }, { status: 201 }); }
  catch { return errorResponse("DUPLICATE_BUDGET", "A budget already exists for this category and month.", 409); }
}
