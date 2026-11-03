const local = new Map<string, { count: number; reset: number }>();
export async function rateLimit(request: Request, key: string, limit: number, windowSeconds: number) {
  const ip = request.headers.get("x-real-ip") ?? request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown"; const redisUrl = process.env.UPSTASH_REDIS_REST_URL, redisToken = process.env.UPSTASH_REDIS_REST_TOKEN;
  if (redisUrl && redisToken) { try { const script = "local n=redis.call('INCR',KEYS[1]); if n==1 then redis.call('EXPIRE',KEYS[1],ARGV[1]) end; return n"; const response = await fetch(`${redisUrl.replace(/\/$/, "")}/pipeline`, { method: "POST", headers: { Authorization: `Bearer ${redisToken}`, "Content-Type": "application/json" }, body: JSON.stringify([["EVAL", script, "1", `ff:rl:${key}:${ip}`, String(windowSeconds)]]), signal: AbortSignal.timeout(3000), cache: "no-store" }); if (!response.ok) return false; const data = await response.json() as Array<{ result?: number }>; return Number(data[0]?.result) <= limit; } catch { return false; } }
  if (process.env.NODE_ENV === "production") return false;
  const now = Date.now(), id = `${key}:${ip}`, item = local.get(id); if (!item || item.reset <= now) { local.set(id, { count: 1, reset: now + windowSeconds * 1000 }); return true; } item.count++; return item.count <= limit;
}
