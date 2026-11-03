import { Prisma, NotificationType } from "@prisma/client";
import { prisma } from "@/lib/prisma";

export async function budgetSnapshot(userId: string, month: number, year: number) {
  const budgets = await prisma.budget.findMany({ where: { userId, month, year }, include: { category: true }, orderBy: { category: { name: "asc" } } });
  const from = new Date(Date.UTC(year, month - 1, 1)); const to = new Date(Date.UTC(year, month, 1));
  const spent = await prisma.transaction.groupBy({ where: { userId, type: "EXPENSE", transactionDate: { gte: from, lt: to } }, by: ["categoryId"], _sum: { amount: true } });
  return budgets.map((budget) => { const actual = spent.find((x) => x.categoryId === budget.categoryId)?._sum.amount ?? new Prisma.Decimal(0); return { ...budget, spent: actual, remaining: budget.amountLimit.minus(actual), utilization: budget.amountLimit.isZero() ? new Prisma.Decimal(0) : actual.div(budget.amountLimit).mul(100) }; });
}

export async function evaluateBudgetAlerts(userId: string, categoryId: string, transactionDate: Date) {
  const month = transactionDate.getUTCMonth() + 1, year = transactionDate.getUTCFullYear();
  const budgets = await prisma.budget.findMany({ where: { userId, categoryId, month, year }, include: { category: true } });
  for (const budget of budgets) {
    const from = new Date(Date.UTC(year, month - 1, 1)), to = new Date(Date.UTC(year, month, 1));
    const sum = await prisma.transaction.aggregate({ where: { userId, categoryId, type: "EXPENSE", transactionDate: { gte: from, lt: to } }, _sum: { amount: true } });
    const actual = sum._sum.amount ?? new Prisma.Decimal(0); const ratio = actual.div(budget.amountLimit);
    const reached = ratio.greaterThanOrEqualTo(1) ? 100 : ratio.greaterThanOrEqualTo(0.9) ? 90 : ratio.greaterThanOrEqualTo(0.75) ? 75 : 0;
    if (!reached) continue;
    const preferences = await prisma.notificationPreference.findUnique({ where: { userId }, select: { budgetAlerts: true } }); if (preferences && !preferences.budgetAlerts) continue;
    const type: NotificationType = reached === 100 ? "BUDGET_EXCEEDED" : "BUDGET_THRESHOLD";
    const title = `${budget.category.name} budget ${reached}%`;
    const dedupeKey = `budget:${budget.id}:${reached}:${year}-${month}`;
    await prisma.notification.upsert({ where: { userId_dedupeKey: { userId, dedupeKey } }, create: { userId, dedupeKey, title, message: `${budget.category.name} spending is ${actual.toFixed(2)} of ${budget.amountLimit.toFixed(2)} for ${month}/${year}.`, type }, update: {} });
  }
}

export async function evaluateSpendingAnomaly(userId: string, categoryId: string, transactionDate: Date) {
  const prefs = await prisma.notificationPreference.findUnique({ where: { userId }, select: { spendingAlerts: true } }); if (prefs && !prefs.spendingAlerts) return;
  const month = transactionDate.getUTCMonth(), year = transactionDate.getUTCFullYear(), day = transactionDate.getUTCDate();
  const currentFrom = new Date(Date.UTC(year, month, 1)), currentTo = new Date(Date.UTC(year, month, day + 1));
  const prevYear = month === 0 ? year - 1 : year, prevMonth = (month + 11) % 12, prevLast = new Date(Date.UTC(prevYear, prevMonth + 1, 0)).getUTCDate();
  const previousFrom = new Date(Date.UTC(prevYear, prevMonth, 1)), previousTo = new Date(Date.UTC(prevYear, prevMonth, Math.min(day, prevLast) + 1));
  const [current, previous, category] = await Promise.all([
    prisma.transaction.aggregate({ where: { userId, categoryId, type: "EXPENSE", transactionDate: { gte: currentFrom, lt: currentTo } }, _sum: { amount: true } }),
    prisma.transaction.aggregate({ where: { userId, categoryId, type: "EXPENSE", transactionDate: { gte: previousFrom, lt: previousTo } }, _sum: { amount: true } }),
    prisma.category.findFirst({ where: { id: categoryId, userId }, select: { name: true } }),
  ]);
  const nowAmount = current._sum.amount ?? new Prisma.Decimal(0), before = previous._sum.amount ?? new Prisma.Decimal(0); if (!category || before.isZero() || nowAmount.lessThan(before.mul("1.5"))) return;
  const dedupeKey = `spending:${categoryId}:${year}-${month + 1}`;
  await prisma.notification.upsert({ where: { userId_dedupeKey: { userId, dedupeKey } }, create: { userId, dedupeKey, title: `Higher spending on ${category.name}`, message: `Spending so far this month is over 50% above the same period last month.`, type: "SPENDING" }, update: {} });
}
