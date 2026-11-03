import { NextResponse } from "next/server";
import { auth } from "@/lib/auth";
import { z } from "zod";

export async function userIdOrResponse() {
  const session = await auth();
  if (!session?.user?.id) return { userId: null, response: NextResponse.json({ error: { code: "UNAUTHORIZED", message: "Sign in to continue." } }, { status: 401 }) };
  return { userId: session.user.id, response: null };
}

export function errorResponse(code: string, message: string, status = 400) {
  return NextResponse.json({ error: { code, message } }, { status });
}

export function dateOnly(date: Date) {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}

export const amountSchema = z.union([z.string(), z.number()]).transform(String).refine((value) => /^(?:0|[1-9]\d{0,14})(?:\.\d{1,4})?$/.test(value) && /[1-9]/.test(value), "Enter a positive amount with up to four decimal places.");
