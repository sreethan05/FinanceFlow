import { NextResponse } from "next/server";
import { z } from "zod";
import { userIdOrResponse, amountSchema, errorResponse, dateOnly } from "@/lib/api";
import { prisma } from "@/lib/prisma";
const schema = z.object({ categoryId: z.string().min(1).optional(), type: z.enum(["INCOME", "EXPENSE"]).optional(), amount: amountSchema.optional(), frequency: z.enum(["DAILY", "WEEKLY", "MONTHLY", "YEARLY", "CUSTOM"]).optional(), interval: z.coerce.number().int().min(1).max(365).optional(), startDate: z.coerce.date().optional(), endDate: z.coerce.date().optional().nullable(), description: z.string().trim().min(1).max(180).optional(), paymentMethod: z.string().trim().max(60).optional().nullable(), isActive: z.boolean().optional() }).refine((x) => !x.endDate || !x.startDate || dateOnly(x.endDate) >= dateOnly(x.startDate), { message: "End date must be after the start date." });
type Ctx = { params: Promise<{ id: string }> };
export async function PATCH(request: Request, { params }: Ctx) {
  const { userId, response } = await userIdOrResponse(); if (response) return response;
  const body = schema.safeParse(await request.json().catch(() => null)); if (!body.success || !Object.keys(body.data ?? {}).length) return errorResponse("INVALID_INPUT", "Enter valid recurring payment changes.");
  const { id } = await params; const rule = await prisma.recurringTransaction.findFirst({ where: { id, userId: userId! } }); if (!rule) return errorResponse("NOT_FOUND", "Recurring transaction not found.", 404);
  const categoryId = body.data.categoryId ?? rule.categoryId, type = body.data.type ?? rule.type;
  if (body.data.categoryId || body.data.type) { const category = await prisma.category.findFirst({ where: { id: categoryId, userId: userId!, type }, select: { id: true } }); if (!category) return errorResponse("INVALID_CATEGORY", "Choose one of your categories for this transaction type."); }
  const startDate = body.data.startDate ? dateOnly(body.data.startDate) : undefined, endDate = body.data.endDate ? dateOnly(body.data.endDate) : body.data.endDate;
  const result = await prisma.recurringTransaction.update({ where: { id }, data: { ...body.data, ...(body.data.amount ? { amount: body.data.amount } : {}), ...(body.data.categoryId ? { categoryId } : {}), ...(body.data.type ? { type } : {}), ...(startDate ? { startDate, nextExecutionDate: startDate } : {}), ...(endDate !== undefined ? { endDate } : {}) } });
  return NextResponse.json({ data: result });
}
export async function DELETE(_request: Request, { params }: Ctx) { const { userId, response } = await userIdOrResponse(); if (response) return response; const { id } = await params; const result = await prisma.recurringTransaction.deleteMany({ where: { id, userId: userId! } }); return result.count ? NextResponse.json({ data: { deleted: true } }) : errorResponse("NOT_FOUND", "Recurring transaction not found.", 404); }
