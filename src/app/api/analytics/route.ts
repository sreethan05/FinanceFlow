import { NextResponse } from "next/server";
import { userIdOrResponse, errorResponse } from "@/lib/api";
import { analyticsSummary } from "@/services/analytics.service";
export async function GET(request: Request) {
  const { userId, response } = await userIdOrResponse(); if (response) return response;
  const url = new URL(request.url), today = new Date(); const to = url.searchParams.has("to") ? new Date(`${url.searchParams.get("to")}T00:00:00.000Z`) : new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth() + 1, 1)); const from = url.searchParams.has("from") ? new Date(`${url.searchParams.get("from")}T00:00:00.000Z`) : new Date(Date.UTC(to.getUTCFullYear(), to.getUTCMonth() - 5, 1));
  if (Number.isNaN(from.getTime()) || Number.isNaN(to.getTime()) || from >= to || to.getTime() - from.getTime() > 366 * 3 * 86400000) return errorResponse("INVALID_RANGE", "Choose a date range of three years or less.");
  return NextResponse.json({ data: await analyticsSummary(userId!, from, to) });
}
