export function formatMoney(value: string, currency = "INR") {
  const [whole = "0", fraction = ""] = value.split(".");
  const formatter = new Intl.NumberFormat("en-IN", { style: "currency", currency, maximumFractionDigits: 2 });
  const parts = formatter.formatToParts(0); const integerIndex = parts.findIndex((part) => part.type === "integer");
  const prefix = parts.slice(0, integerIndex).map((part) => part.value).join("");
  const suffix = parts.slice(integerIndex + 1).filter((part) => part.type === "literal").map((part) => part.value).join("");
  const grouped = new Intl.NumberFormat("en-IN", { maximumFractionDigits: 0 }).format(BigInt(whole));
  return `${prefix}${grouped}${fraction ? `.${fraction.replace(/0+$/, "")}` : ""}${suffix}`;
}
