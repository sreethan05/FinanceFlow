import { NextResponse } from "next/server";
import { Prisma } from "@prisma/client";
import { auth } from "@/lib/auth";
import { prisma } from "@/lib/prisma";
import { transactionSchema } from "@/lib/validations/transaction";
import { evaluateBudgetAlerts, evaluateSpendingAnomaly } from "@/services/budget.service";

export async function GET(request: Request) {
  const session = await auth();
  if (!session?.user?.id) return NextResponse.json({ error: { code: "UNAUTHORIZED", message: "Sign in to continue." } }, { status: 401 });
  const url = new URL(request.url);
  const page = Math.max(1, Number(url.searchParams.get("page")) || 1);
  const pageSize = Math.min(50, Math.max(1, Number(url.searchParams.get("pageSize")) || 20));
  const search = url.searchParams.get("search")?.slice(0, 100);
  const type = url.searchParams.get("type");
  const categoryId = url.searchParams.get("categoryId")?.slice(0, 64); const fromText = url.searchParams.get("from"), toText = url.searchParams.get("to"); const from = fromText ? new Date(`${fromText}T00:00:00Z`) : undefined, to = toText ? new Date(`${toText}T00:00:00Z`) : undefined; if (to) to.setUTCDate(to.getUTCDate() + 1);
  if ((from && Number.isNaN(from.getTime())) || (to && Number.isNaN(to.getTime())) || (from && to && from > to)) return NextResponse.json({ error: { code: "INVALID_RANGE", message: "Choose valid transaction dates." } }, { status: 400 });
  const where: Prisma.TransactionWhereInput = { userId: session.user.id, ...(type === "INCOME" || type === "EXPENSE" ? { type } : {}), ...(categoryId ? { categoryId } : {}), ...(from || to ? { transactionDate: { ...(from ? { gte: from } : {}), ...(to ? { lt: to } : {}) } } : {}), ...(search ? { OR: [{ description: { contains: search, mode: "insensitive" } }, { category: { name: { contains: search, mode: "insensitive" } } }] } : {}) };
  const sort = url.searchParams.get("sort"); const orderBy: Prisma.TransactionOrderByWithRelationInput[] = sort === "amount_asc" ? [{ amount: "asc" }, { transactionDate: "desc" }] : sort === "amount_desc" ? [{ amount: "desc" }, { transactionDate: "desc" }] : sort === "date_asc" ? [{ transactionDate: "asc" }, { createdAt: "asc" }] : [{ transactionDate: "desc" }, { createdAt: "desc" }];
  const [data, total] = await Promise.all([
    prisma.transaction.findMany({ where, include: { category: { select: { id: true, name: true, color: true, icon: true } } }, orderBy, skip: (page - 1) * pageSize, take: pageSize }),
    prisma.transaction.count({ where }),
  ]);
  return NextResponse.json({ data, page, pageSize, total });
}

export async function POST(request: Request) {
  const session = await auth();
  if (!session?.user?.id) return NextResponse.json({ error: { code: "UNAUTHORIZED", message: "Sign in to continue." } }, { status: 401 });
  const parsed = transactionSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: { code: "INVALID_INPUT", message: "Check the transaction details." } }, { status: 400 });
  const category = await prisma.category.findFirst({ where: { id: parsed.data.categoryId, userId: session.user.id, type: parsed.data.type }, select: { id: true } });
  if (!category) return NextResponse.json({ error: { code: "INVALID_CATEGORY", message: "Choose a category for this transaction." } }, { status: 400 });
  const transaction = await prisma.transaction.create({ data: { ...parsed.data, userId: session.user.id, transactionDate: new Date(Date.UTC(parsed.data.transactionDate.getFullYear(), parsed.data.transactionDate.getMonth(), parsed.data.transactionDate.getDate())) }, include: { category: true } });
  if (transaction.type === "EXPENSE") { await evaluateBudgetAlerts(session.user.id, transaction.categoryId, transaction.transactionDate); await evaluateSpendingAnomaly(session.user.id, transaction.categoryId, transaction.transactionDate); }
  return NextResponse.json({ data: transaction }, { status: 201 });
}
