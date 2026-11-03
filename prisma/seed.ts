import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();
const categories = [
  ["Salary", "INCOME", "#16856b"], ["Freelancing", "INCOME", "#348c78"], ["Investments", "INCOME", "#5b9b80"], ["Other income", "INCOME", "#77a88f"],
  ["Food", "EXPENSE", "#e17a62"], ["Shopping", "EXPENSE", "#d89158"], ["Transport", "EXPENSE", "#7d91ad"], ["Rent", "EXPENSE", "#8978a6"], ["Utilities", "EXPENSE", "#d4a854"], ["Healthcare", "EXPENSE", "#62a39c"], ["Education", "EXPENSE", "#7d8fc3"], ["Entertainment", "EXPENSE", "#bd7c9b"], ["Subscriptions", "EXPENSE", "#7689a7"], ["Other expenses", "EXPENSE", "#8a9992"],
] as const;

async function main() {
  const email = process.env.SEED_EMAIL;
  if (!email) { console.info("Set SEED_EMAIL to create a development account; no sample account created."); return; }
  const existing = await prisma.user.findUnique({ where: { email }, select: { id: true } });
  if (!existing) { console.info("SEED_EMAIL must belong to a registered account. Register in the app, then rerun this seed."); return; }
  await prisma.category.createMany({ data: categories.map(([name, type, color]) => ({ userId: existing.id, name, type, color, isDefault: true })), skipDuplicates: true });
  await prisma.notificationPreference.upsert({ where: { userId: existing.id }, create: { userId: existing.id }, update: {} });
}
main().finally(() => prisma.$disconnect());
