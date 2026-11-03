import { NextResponse } from "next/server";
import { auth } from "@/lib/auth";
import { prisma } from "@/lib/prisma";
import { transactionSchema } from "@/lib/validations/transaction";
import { evaluateBudgetAlerts, evaluateSpendingAnomaly } from "@/services/budget.service";

type Context = { params: Promise<{ id: string }> };
export async function PATCH(request: Request, { params }: Context) {
  const session = await auth();
  if (!session?.user?.id) return NextResponse.json({ error: { code: "UNAUTHORIZED", message: "Sign in to continue." } }, { status: 401 });
  const parsed = transactionSchema.partial().safeParse(await request.json().catch(() => null));
  if (!parsed.success || !Object.keys(parsed.data ?? {}).length) return NextResponse.json({ error: { code: "INVALID_INPUT", message: "Check the transaction details." } }, { status: 400 });
  const { id } = await params;
  const current = await prisma.transaction.findFirst({ where: { id, userId: session.user.id }, select: { id: true, type: true, categoryId: true } });
  if (!current) return NextResponse.json({ error: { code: "NOT_FOUND", message: "Transaction not found." } }, { status: 404 });
  const type = parsed.data.type ?? current.type;
  const categoryId = parsed.data.categoryId ?? current.categoryId;
  const category = await prisma.category.findFirst({ where: { id: categoryId, userId: session.user.id, type }, select: { id: true } });
  if (!category) return NextResponse.json({ error: { code: "INVALID_CATEGORY", message: "Choose a category for this transaction." } }, { status: 400 });
  const transaction = await prisma.transaction.update({ where: { id }, data: { ...parsed.data, ...(parsed.data.transactionDate ? { transactionDate: new Date(Date.UTC(parsed.data.transactionDate.getFullYear(), parsed.data.transactionDate.getMonth(), parsed.data.transactionDate.getDate())) } : {}) }, include: { category: true } });
  if (transaction.type === "EXPENSE") { await evaluateBudgetAlerts(session.user.id, transaction.categoryId, transaction.transactionDate); await evaluateSpendingAnomaly(session.user.id, transaction.categoryId, transaction.transactionDate); }
  return NextResponse.json({ data: transaction });
}
export async function DELETE(_request: Request, { params }: Context) {
  const session = await auth();
  if (!session?.user?.id) return NextResponse.json({ error: { code: "UNAUTHORIZED", message: "Sign in to continue." } }, { status: 401 });
  const { id } = await params;
  const result = await prisma.transaction.deleteMany({ where: { id, userId: session.user.id } });
  return result.count ? NextResponse.json({ data: { deleted: true } }) : NextResponse.json({ error: { code: "NOT_FOUND", message: "Transaction not found." } }, { status: 404 });
}
