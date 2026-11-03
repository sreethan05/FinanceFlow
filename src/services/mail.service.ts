export class MailConfigurationError extends Error {}
export function mailConfigured() { return Boolean(process.env.MAIL_API_KEY && process.env.MAIL_FROM); }
export async function sendMail(to: string, subject: string, text: string) {
  const apiKey = process.env.MAIL_API_KEY, from = process.env.MAIL_FROM;
  if (!apiKey || !from) throw new MailConfigurationError("Configure MAIL_API_KEY and MAIL_FROM to send account emails.");
  const response = await fetch(process.env.MAIL_API_URL ?? "https://api.resend.com/emails", { method: "POST", headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" }, body: JSON.stringify({ from, to: [to], subject, text }), signal: AbortSignal.timeout(10000), cache: "no-store" });
  if (!response.ok) throw new Error("Mail provider request failed.");
}
