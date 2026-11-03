import { NextResponse } from "next/server";
import { InsightType } from "@prisma/client";
import { z } from "zod";
import { userIdOrResponse, errorResponse } from "@/lib/api";
import { prisma } from "@/lib/prisma";
import { analyticsSummary } from "@/services/analytics.service";
import { AIConfigurationError, AIProviderError, aiCompletion } from "@/services/ai.provider";
import { rateLimit } from "@/lib/rate-limit";
const typeSchema = z.enum(["SPENDING_ANALYSIS", "MONTHLY_REPORT", "BUDGET_RECOMMENDATION", "FINANCIAL_HEALTH"]);
const outputSchema = z.object({ summary: z.string().min(20).max(1000), trends: z.array(z.string().min(5).max(300)).max(4), recommendations: z.array(z.string().min(5).max(300)).max(3) });
export async function GET() { const { userId, response } = await userIdOrResponse(); if (response) return response; return NextResponse.json({ data: await prisma.aIInsight.findMany({ where: { userId: userId! }, orderBy: { createdAt: "desc" }, take: 20 }) }); }
export async function POST(request: Request) {
  const { userId, response } = await userIdOrResponse(); if (response) return response;
  if (!await rateLimit(request, "insights", 10, 86400)) return errorResponse("RATE_LIMITED", "Daily insight generation limit reached. Try again tomorrow.", 429);
  const body = z.object({ type: typeSchema.default("MONTHLY_REPORT"), from: z.coerce.date().optional(), to: z.coerce.date().optional(), refresh: z.boolean().default(false) }).safeParse(await request.json().catch(() => null)); if (!body.success) return errorResponse("INVALID_INPUT", "Choose a valid insight period.");
  const now = new Date(), from = body.data.from ?? new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1)), to = body.data.to ?? new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1)); if (from >= to || to.getTime() - from.getTime() > 366 * 3 * 86400000) return errorResponse("INVALID_RANGE", "Choose a period of three years or less.");
  const cached = !body.data.refresh && await prisma.aIInsight.findUnique({ where: { userId_insightType_periodStart_periodEnd: { userId: userId!, insightType: body.data.type as InsightType, periodStart: from, periodEnd: to } } }); if (cached) return NextResponse.json({ data: { ...cached, content: JSON.parse(cached.content) } });
  const summary = await analyticsSummary(userId!, from, to);
  const context = { currency: (await prisma.user.findUnique({ where: { id: userId! }, select: { currency: true } }))?.currency ?? "INR", period: { from: from.toISOString().slice(0, 10), to: to.toISOString().slice(0, 10) }, totals: { income: summary.totals.income.toString(), expenses: summary.totals.expenses.toString(), net: summary.totals.net.toString(), savingsRatePercent: summary.totals.savingsRate.toFixed(1), previousExpenses: summary.totals.previousExpenses.toString() }, categories: summary.categoryBreakdown.slice(0, 5).map((x) => ({ name: x.name, amount: x.amount.toString(), sharePercent: x.percentage.toFixed(1) })) };
  try {
    const raw = await aiCompletion([{ role: "system", content: `You are an informational personal finance coach. Use only the supplied figures. Never invent arithmetic or describe advice as guaranteed. Return JSON with summary (string), trends (array up to 4), recommendations (array up to 3).` }, { role: "user", content: JSON.stringify({ requestedInsight: body.data.type, financialSummary: context }) }], { json: true, maxTokens: 650 });
    const parsed = outputSchema.safeParse(JSON.parse(raw)); if (!parsed.success) throw new AIProviderError("AI response did not match the expected format.");
    const content = JSON.stringify(parsed.data); const data = await prisma.aIInsight.upsert({ where: { userId_insightType_periodStart_periodEnd: { userId: userId!, insightType: body.data.type, periodStart: from, periodEnd: to } }, create: { userId: userId!, insightType: body.data.type, periodStart: from, periodEnd: to, content }, update: { content, createdAt: new Date() } });
    const prefs = await prisma.notificationPreference.findUnique({ where: { userId: userId! }, select: { monthlySummary: true } }); if ((!prefs || prefs.monthlySummary) && body.data.type === "MONTHLY_REPORT") await prisma.notification.upsert({ where: { userId_dedupeKey: { userId: userId!, dedupeKey: `summary:${from.toISOString().slice(0, 10)}:${to.toISOString().slice(0, 10)}` } }, create: { userId: userId!, dedupeKey: `summary:${from.toISOString().slice(0, 10)}:${to.toISOString().slice(0, 10)}`, title: "Monthly summary available", message: "Your financial summary has been generated and is ready to review.", type: "SUMMARY" }, update: {} });
    return NextResponse.json({ data: { ...data, content: parsed.data } });
  } catch (error) { if (error instanceof AIConfigurationError) return errorResponse("AI_NOT_CONFIGURED", error.message, 503); return errorResponse("AI_UNAVAILABLE", error instanceof AIProviderError ? error.message : "AI insights are temporarily unavailable.", 502); }
}
