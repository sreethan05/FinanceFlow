import { createHash, randomUUID } from "node:crypto";
import { mkdir, writeFile, unlink } from "node:fs/promises";
import path from "node:path";
import { NextResponse } from "next/server";
import { z } from "zod";
import { userIdOrResponse, errorResponse } from "@/lib/api";
import { prisma } from "@/lib/prisma";
import { AIConfigurationError, AIProviderError, aiVision } from "@/services/ai.provider";
import { rateLimit } from "@/lib/rate-limit";

export const runtime = "nodejs";
const outputSchema = z.object({ merchant: z.string().max(160).nullable(), transactionDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).nullable(), totalAmount: z.string().regex(/^\d{1,15}(?:\.\d{1,4})?$/).nullable(), taxAmount: z.string().regex(/^\d{1,15}(?:\.\d{1,4})?$/).nullable(), currency: z.string().regex(/^[A-Z]{3}$/).nullable(), suggestedCategory: z.string().max(50).nullable(), paymentMethod: z.string().max(60).nullable() });
function detect(bytes: Buffer) { if (bytes.subarray(0, 3).equals(Buffer.from([0xff, 0xd8, 0xff]))) return { mime: "image/jpeg", ext: "jpg" }; if (bytes.subarray(0, 8).equals(Buffer.from([0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a]))) return { mime: "image/png", ext: "png" }; if (bytes.toString("ascii", 0, 4) === "RIFF" && bytes.toString("ascii", 8, 12) === "WEBP") return { mime: "image/webp", ext: "webp" }; return null; }
export async function POST(request: Request) {
  const { userId, response } = await userIdOrResponse(); if (response) return response;
  if (!await rateLimit(request, "receipt-scan", 20, 86400)) return errorResponse("RATE_LIMITED", "Daily receipt scan limit reached. Try again tomorrow.", 429);
  const form = await request.formData().catch(() => null); const file = form?.get("file"); if (!(file instanceof File)) return errorResponse("INVALID_FILE", "Choose a JPG, PNG, or WebP receipt image.");
  if (file.size < 1 || file.size > 5 * 1024 * 1024) return errorResponse("INVALID_FILE", "Receipt images must be 5 MB or smaller.");
  const bytes = Buffer.from(await file.arrayBuffer()), detected = detect(bytes); if (!detected) return errorResponse("INVALID_FILE", "The file contents are not a supported image.");
  const contentHash = createHash("sha256").update(bytes).digest("hex"); const existing = await prisma.receipt.findUnique({ where: { userId_contentHash: { userId: userId!, contentHash } }, select: { id: true } }); if (existing) return errorResponse("DUPLICATE_RECEIPT", "This receipt has already been uploaded.", 409);
  let savedFile: string | undefined;
  try {
    const raw = await aiVision("Read this receipt. Return JSON only with merchant, transactionDate (YYYY-MM-DD), totalAmount, taxAmount, currency (ISO 4217), suggestedCategory, paymentMethod. Use null for fields you cannot read. Do not guess. Amounts must be decimal strings.", detected.mime, bytes);
    const parsed = outputSchema.safeParse(JSON.parse(raw)); if (!parsed.success) throw new AIProviderError("Receipt scan returned an invalid extraction.");
    const id = randomUUID(), storageKey = `${id}.${detected.ext}`, storageRoot = path.resolve(process.env.RECEIPT_STORAGE_DIR ?? path.join(process.cwd(), ".private-receipts")), filePath = path.resolve(storageRoot, storageKey);
    if (!filePath.startsWith(`${storageRoot}${path.sep}`)) return errorResponse("INVALID_PATH", "Receipt storage path is invalid.", 500);
    await mkdir(path.dirname(filePath), { recursive: true }); await writeFile(filePath, bytes, { flag: "wx", mode: 0o600 }); savedFile=filePath;
    const data = await prisma.receipt.create({ data: { id, userId: userId!, storageKey, merchant: parsed.data.merchant, totalAmount: parsed.data.totalAmount, receiptDate: parsed.data.transactionDate ? new Date(`${parsed.data.transactionDate}T00:00:00Z`) : null, extractedData: parsed.data, contentHash, processingStatus: "PROCESSED" }, select: { id: true, merchant: true, totalAmount: true, receiptDate: true, extractedData: true, processingStatus: true } });
    savedFile = undefined; return NextResponse.json({ data }, { status: 201 });
  } catch (error) { if (savedFile) await unlink(savedFile).catch(() => undefined); if (error instanceof AIConfigurationError) return errorResponse("AI_NOT_CONFIGURED", error.message, 503); return errorResponse("RECEIPT_SCAN_FAILED", error instanceof AIProviderError ? error.message : "Receipt scan failed. Please retry or enter the transaction manually.", 502); }
}
