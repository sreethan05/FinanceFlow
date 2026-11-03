import { timingSafeEqual } from "node:crypto";
import { NextResponse } from "next/server";
import { executeDueRecurring } from "@/services/recurring.service";

export async function POST(request: Request) {
  const secret = process.env.CRON_SECRET; const supplied = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  if (!secret || supplied.length !== secret.length || !timingSafeEqual(Buffer.from(supplied), Buffer.from(secret))) return NextResponse.json({ error: { code: "UNAUTHORIZED", message: "Unauthorized." } }, { status: 401 });
  try { return NextResponse.json({ data: await executeDueRecurring() }); }
  catch { return NextResponse.json({ error: { code: "JOB_FAILED", message: "Recurring transactions could not be processed." } }, { status: 500 }); }
}
