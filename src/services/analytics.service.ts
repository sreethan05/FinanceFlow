import { Prisma } from "@prisma/client";
import { prisma } from "@/lib/prisma";

export async function analyticsSummary(userId: string, from: Date, to: Date) {
  const previousLength = to.getTime() - from.getTime(); const previousFrom = new Date(from.getTime() - previousLength);
  const [income, expenses, categories, transactions, previousIncome, previousExpenses] = await Promise.all([
    prisma.transaction.aggregate({ where: { userId, type: "INCOME", transactionDate: { gte: from, lt: to } }, _sum: { amount: true } }),
    prisma.transaction.aggregate({ where: { userId, type: "EXPENSE", transactionDate: { gte: from, lt: to } }, _sum: { amount: true } }),
    prisma.transaction.groupBy({ where: { userId, type: "EXPENSE", transactionDate: { gte: from, lt: to } }, by: ["categoryId"], _sum: { amount: true }, _count: true, orderBy: { _sum: { amount: "desc" } } }),
    prisma.transaction.findMany({ where: { userId, transactionDate: { gte: from, lt: to } }, select: { amount: true, type: true, transactionDate: true } }),
    prisma.transaction.aggregate({ where: { userId, type: "INCOME", transactionDate: { gte: previousFrom, lt: from } }, _sum: { amount: true } }),
    prisma.transaction.aggregate({ where: { userId, type: "EXPENSE", transactionDate: { gte: previousFrom, lt: from } }, _sum: { amount: true } }),
  ]);
  const totalIncome = income._sum.amount ?? new Prisma.Decimal(0); const totalExpenses = expenses._sum.amount ?? new Prisma.Decimal(0);
  const previousExpense = previousExpenses._sum.amount ?? new Prisma.Decimal(0); const previousIncomeAmount = previousIncome._sum.amount ?? new Prisma.Decimal(0);
  const ids = categories.map((x) => x.categoryId); const categoryRows = await prisma.category.findMany({ where: { userId, id: { in: ids } }, select: { id: true, name: true, color: true } });
  const categoryBreakdown = categories.map((row) => { const category = categoryRows.find((x) => x.id === row.categoryId); const amount = row._sum.amount ?? new Prisma.Decimal(0); return { categoryId: row.categoryId, name: category?.name ?? "Category", color: category?.color ?? "#64748b", amount, count: row._count, percentage: totalExpenses.isZero() ? new Prisma.Decimal(0) : amount.div(totalExpenses).mul(100) }; });
  const monthly = new Map<string, { income: Prisma.Decimal; expenses: Prisma.Decimal }>();
  for (const row of transactions) { const key = `${row.transactionDate.getUTCFullYear()}-${String(row.transactionDate.getUTCMonth() + 1).padStart(2, "0")}`; const item = monthly.get(key) ?? { income: new Prisma.Decimal(0), expenses: new Prisma.Decimal(0) }; if (row.type === "INCOME") item.income = item.income.plus(row.amount); else item.expenses = item.expenses.plus(row.amount); monthly.set(key, item); }
  return { period: { from, to }, totals: { income: totalIncome, expenses: totalExpenses, net: totalIncome.minus(totalExpenses), savingsRate: totalIncome.isZero() ? new Prisma.Decimal(0) : totalIncome.minus(totalExpenses).div(totalIncome).mul(100), previousIncome: previousIncomeAmount, previousExpenses: previousExpense }, categoryBreakdown, monthly: [...monthly.entries()].sort(([a], [b]) => a.localeCompare(b)).map(([month, values]) => ({ month, ...values, net: values.income.minus(values.expenses) })) };
}
