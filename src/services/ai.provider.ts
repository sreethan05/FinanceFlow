export class AIConfigurationError extends Error {}
export class AIProviderError extends Error {}
export async function aiCompletion(messages: Array<Record<string, unknown>>, options: { json?: boolean; maxTokens?: number } = {}) {
  const apiKey = process.env.AI_API_KEY; const base = process.env.AI_BASE_URL?.replace(/\/$/, ""); const model = process.env.AI_MODEL;
  if (!apiKey || !base || !model) throw new AIConfigurationError("Configure AI_API_KEY, AI_BASE_URL, and AI_MODEL to enable AI features.");
  const response = await fetch(`${base}/chat/completions`, { method: "POST", headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" }, body: JSON.stringify({ model, messages, max_tokens: options.maxTokens ?? 700, ...(options.json ? { response_format: { type: "json_object" } } : {}) }), signal: AbortSignal.timeout(45000), cache: "no-store" });
  if (!response.ok) throw new AIProviderError(`AI provider returned status ${response.status}.`);
  const data = await response.json() as { choices?: Array<{ message?: { content?: string } }> }; const content = data.choices?.[0]?.message?.content;
  if (!content) throw new AIProviderError("AI provider returned an empty response.");
  return content;
}

export async function aiVision(prompt: string, mimeType: string, image: Buffer) {
  const apiKey = process.env.AI_API_KEY; const base = process.env.AI_BASE_URL?.replace(/\/$/, ""); const model = process.env.AI_VISION_MODEL ?? process.env.AI_MODEL;
  if (!apiKey || !base || !model) throw new AIConfigurationError("Configure AI_API_KEY, AI_BASE_URL, and AI_VISION_MODEL (or AI_MODEL) to enable receipt scanning.");
  const response = await fetch(`${base}/chat/completions`, { method: "POST", headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" }, body: JSON.stringify({ model, max_tokens: 450, response_format: { type: "json_object" }, messages: [{ role: "user", content: [{ type: "text", text: prompt }, { type: "image_url", image_url: { url: `data:${mimeType};base64,${image.toString("base64")}` } }] }] }), signal: AbortSignal.timeout(60000), cache: "no-store" });
  if (!response.ok) throw new AIProviderError(`AI vision provider returned status ${response.status}.`);
  const data = await response.json() as { choices?: Array<{ message?: { content?: string } }> }; const content = data.choices?.[0]?.message?.content;
  if (!content) throw new AIProviderError("AI vision provider returned an empty response."); return content;
}
