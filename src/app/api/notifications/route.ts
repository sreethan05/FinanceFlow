import { NextResponse } from "next/server";
import { z } from "zod";
import { userIdOrResponse, errorResponse } from "@/lib/api";
import { prisma } from "@/lib/prisma";
const schema = z.object({ ids: z.array(z.string()).max(100).optional(), markAllRead: z.boolean().default(false) });
export async function GET() { const { userId, response } = await userIdOrResponse(); if (response) return response; const data = await prisma.notification.findMany({ where: { userId: userId! }, orderBy: { createdAt: "desc" }, take: 50 }); const unread = await prisma.notification.count({ where: { userId: userId!, isRead: false } }); return NextResponse.json({ data, unread }); }
export async function PATCH(request: Request) { const { userId, response } = await userIdOrResponse(); if (response) return response; const body = schema.safeParse(await request.json().catch(() => null)); if (!body.success) return errorResponse("INVALID_INPUT", "Invalid notification update."); await prisma.notification.updateMany({ where: { userId: userId!, ...(body.data.markAllRead ? { isRead: false } : { id: { in: body.data.ids ?? [] } }) }, data: { isRead: true } }); return NextResponse.json({ data: { updated: true } }); }
