import { NextResponse } from "next/server";
import { z } from "zod";
import { userIdOrResponse, amountSchema, errorResponse } from "@/lib/api";
import { prisma } from "@/lib/prisma";
const schema = z.object({ amountLimit: amountSchema.optional(), month: z.coerce.number().int().min(1).max(12).optional(), year: z.coerce.number().int().min(2000).max(2200).optional() });
type Ctx = { params: Promise<{ id: string }> };
export async function PATCH(request: Request, { params }: Ctx) { const { userId, response } = await userIdOrResponse(); if (response) return response; const body = schema.safeParse(await request.json().catch(() => null)); if (!body.success || !Object.keys(body.data ?? {}).length) return errorResponse("INVALID_INPUT", "Enter valid budget changes."); const { id } = await params; try { const result = await prisma.budget.updateMany({ where: { id, userId: userId! }, data: body.data }); if (!result.count) return errorResponse("NOT_FOUND", "Budget not found.", 404); return NextResponse.json({ data: await prisma.budget.findFirst({ where: { id, userId: userId! } }) }); } catch { return errorResponse("DUPLICATE_BUDGET", "A budget already exists for that category and month.", 409); } }
export async function DELETE(_request: Request, { params }: Ctx) { const { userId, response } = await userIdOrResponse(); if (response) return response; const { id } = await params; const result = await prisma.budget.deleteMany({ where: { id, userId: userId! } }); return result.count ? NextResponse.json({ data: { deleted: true } }) : errorResponse("NOT_FOUND", "Budget not found.", 404); }
