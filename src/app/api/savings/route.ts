import { NextResponse } from "next/server";
import { z } from "zod";
import { userIdOrResponse, amountSchema, errorResponse, dateOnly } from "@/lib/api";
import { prisma } from "@/lib/prisma";
import { Prisma } from "@prisma/client";
import { notifyGoalMilestones } from "@/services/savings.service";
const schema = z.object({ name: z.string().trim().min(2).max(120), targetAmount: amountSchema, currentAmount: amountSchema.optional(), targetDate: z.coerce.date().optional().nullable() });
export async function GET() { const { userId, response } = await userIdOrResponse(); if (response) return response; const data = await prisma.savingsGoal.findMany({ where: { userId: userId! }, orderBy: [{ status: "asc" }, { targetDate: "asc" }] }); return NextResponse.json({ data }); }
export async function POST(request: Request) { const { userId, response } = await userIdOrResponse(); if (response) return response; const body = schema.safeParse(await request.json().catch(() => null)); if (!body.success) return errorResponse("INVALID_INPUT", "Enter a goal name and valid target amount."); const currentAmount = body.data.currentAmount ?? "0"; const status = new Prisma.Decimal(currentAmount).greaterThanOrEqualTo(body.data.targetAmount) ? "COMPLETED" : "ACTIVE"; const data = await prisma.savingsGoal.create({ data: { ...body.data, targetDate: body.data.targetDate ? dateOnly(body.data.targetDate) : null, userId: userId!, status } }); await notifyGoalMilestones(userId!, data.id, data.name, data.currentAmount, data.targetAmount); return NextResponse.json({ data }, { status: 201 }); }
