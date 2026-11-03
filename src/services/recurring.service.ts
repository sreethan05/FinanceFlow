import { Prisma } from "@prisma/client";
import { prisma } from "@/lib/prisma";
import { evaluateBudgetAlerts } from "@/services/budget.service";
import { nextOccurrence } from "@/lib/recurrence";
export { nextOccurrence } from "@/lib/recurrence";

export async function executeDueRecurring(now = new Date(), limit = 100) {
  const today = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
  const rules = await prisma.recurringTransaction.findMany({ where: { isActive: true, nextExecutionDate: { lte: today } }, orderBy: { nextExecutionDate: "asc" }, take: limit });
  let executed = 0;
  for (const rule of rules) {
    let scheduled = rule.nextExecutionDate;
    while (scheduled <= today && (!rule.endDate || scheduled <= rule.endDate)) {
      try {
        await prisma.$transaction(async (tx) => {
          const occurrence = await tx.recurringOccurrence.create({ data: { recurringTransactionId: rule.id, scheduledFor: scheduled } });
          const transaction = await tx.transaction.create({ data: { userId: rule.userId, categoryId: rule.categoryId, amount: rule.amount, type: rule.type, description: rule.description, transactionDate: scheduled, paymentMethod: rule.paymentMethod } });
          await tx.recurringOccurrence.update({ where: { id: occurrence.id }, data: { transactionId: transaction.id } });
          const next = nextOccurrence(scheduled, rule.frequency, rule.interval);
          await tx.recurringTransaction.update({ where: { id: rule.id }, data: { nextExecutionDate: next, ...(rule.endDate && next > rule.endDate ? { isActive: false } : {}) } });
        }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
        executed++;
        if (rule.type === "EXPENSE") await evaluateBudgetAlerts(rule.userId, rule.categoryId, scheduled);
      } catch (error) {
        if (error instanceof Prisma.PrismaClientKnownRequestError && (error.code === "P2002" || error.code === "P2034")) break;
        throw error;
      }
      scheduled = nextOccurrence(scheduled, rule.frequency, rule.interval);
    }
    if (rule.endDate && scheduled > rule.endDate) await prisma.recurringTransaction.updateMany({ where: { id: rule.id }, data: { isActive: false } });
  }
  const horizon = new Date(today.getTime() + 3 * 86400000); const upcoming = await prisma.recurringTransaction.findMany({ where: { isActive: true, nextExecutionDate: { gt: today, lte: horizon } }, include: { category: { select: { name: true } } }, take: 500 });
  for (const rule of upcoming) { const preference = await prisma.notificationPreference.findUnique({ where: { userId: rule.userId }, select: { recurringReminders: true } }); if (preference && !preference.recurringReminders) continue; const date = rule.nextExecutionDate.toISOString().slice(0, 10), dedupeKey = `recurring:${rule.id}:${date}`; await prisma.notification.upsert({ where: { userId_dedupeKey: { userId: rule.userId, dedupeKey } }, create: { userId: rule.userId, dedupeKey, title: `Upcoming ${rule.type === "EXPENSE" ? "payment" : "income"}: ${rule.description}`, message: `Scheduled for ${date} (${rule.category.name}).`, type: "UPCOMING_PAYMENT" }, update: {} }); }
  return { executed, checked: rules.length };
}
