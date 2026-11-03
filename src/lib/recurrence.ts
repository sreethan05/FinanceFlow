export type Frequency = "DAILY"|"WEEKLY"|"MONTHLY"|"YEARLY"|"CUSTOM";
export function nextOccurrence(current: Date, frequency: Frequency, interval = 1) {
  const date = new Date(Date.UTC(current.getUTCFullYear(), current.getUTCMonth(), current.getUTCDate()));
  if (frequency === "DAILY" || frequency === "CUSTOM") date.setUTCDate(date.getUTCDate() + interval);
  if (frequency === "WEEKLY") date.setUTCDate(date.getUTCDate() + 7 * interval);
  if (frequency === "MONTHLY") { const day = date.getUTCDate(); date.setUTCDate(1); date.setUTCMonth(date.getUTCMonth() + interval); date.setUTCDate(Math.min(day, new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + 1, 0)).getUTCDate())); }
  if (frequency === "YEARLY") { const month = date.getUTCMonth(), day = date.getUTCDate(); date.setUTCDate(1); date.setUTCFullYear(date.getUTCFullYear() + interval); date.setUTCMonth(month); date.setUTCDate(Math.min(day, new Date(Date.UTC(date.getUTCFullYear(), month + 1, 0)).getUTCDate())); }
  return date;
}
