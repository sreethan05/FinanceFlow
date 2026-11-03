import { z } from "zod";

export const transactionSchema = z.object({
  amount: z.union([z.string(), z.number()]).transform(String).refine((value) => /^(?:0|[1-9]\d{0,14})(?:\.\d{1,4})?$/.test(value) && /[1-9]/.test(value), "Enter a positive amount with up to four decimal places."),
  type: z.enum(["INCOME", "EXPENSE"]),
  categoryId: z.string().min(1),
  description: z.string().trim().min(1).max(180),
  transactionDate: z.coerce.date(),
  paymentMethod: z.string().trim().max(60).optional().nullable(),
  notes: z.string().trim().max(1000).optional().nullable(),
});
