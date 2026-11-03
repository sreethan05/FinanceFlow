import { Prisma } from "@prisma/client";
import { prisma } from "@/lib/prisma";
export async function notifyGoalMilestones(userId: string, goalId: string, name: string, current: Prisma.Decimal, target: Prisma.Decimal) {
  const prefs = await prisma.notificationPreference.findUnique({ where: { userId }, select: { goalMilestones: true } }); if (prefs && !prefs.goalMilestones) return;
  const percent = target.isZero() ? new Prisma.Decimal(0) : current.div(target).mul(100);
  for (const threshold of [25, 50, 75, 100]) if (percent.greaterThanOrEqualTo(threshold)) { const dedupeKey = `goal:${goalId}:${threshold}`; await prisma.notification.upsert({ where: { userId_dedupeKey: { userId, dedupeKey } }, create: { userId, dedupeKey, title: `${name}: ${threshold}% saved`, message: `You have reached ${threshold}% of this savings target.`, type: threshold === 100 ? "MILESTONE" : "SAVINGS" }, update: {} }); }
}
