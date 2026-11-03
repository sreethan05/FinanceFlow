import { NextResponse } from "next/server";
import { userIdOrResponse } from "@/lib/api";
import { prisma } from "@/lib/prisma";
export async function GET() { const { userId, response } = await userIdOrResponse(); if (response) return response; const data = await prisma.receipt.findMany({ where: { userId: userId! }, select: { id: true, merchant: true, totalAmount: true, receiptDate: true, extractedData: true, processingStatus: true, createdAt: true }, orderBy: { createdAt: "desc" }, take: 100 }); return NextResponse.json({ data }); }
