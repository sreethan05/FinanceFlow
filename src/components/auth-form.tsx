"use client";
import { useState } from "react";
import { signIn } from "next-auth/react";
import { useRouter } from "next/navigation";
import Link from "next/link";

export function AuthForm({ mode, googleEnabled = false }: { mode: "login" | "register"; googleEnabled?: boolean }) {
  const [error, setError] = useState(""); const [busy, setBusy] = useState(false); const router = useRouter();
  async function submit(form: FormData) {
    setBusy(true); setError("");
    const email = String(form.get("email")); const password = String(form.get("password"));
    if (mode === "register") {
      const response = await fetch("/api/auth/register", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name: form.get("name"), email, password }) });
      const body = await response.json();
      if (!response.ok) { setError(body.error?.message ?? "Could not create account."); setBusy(false); return; }
    }
    const result = await signIn("credentials", { email, password, redirect: false });
    if (result?.error) { setError("Those sign-in details don't match an account."); setBusy(false); return; }
    router.push("/overview"); router.refresh();
  }
  return <form action={submit} className="mt-8 space-y-4">
    {mode === "register" && <label className="block text-sm font-medium">Full name<input className="ff-input mt-2" name="name" autoComplete="name" required maxLength={80} /></label>}
    <label className="block text-sm font-medium">Email address<input className="ff-input mt-2" name="email" type="email" autoComplete="email" required maxLength={254} /></label>
    <label className="block text-sm font-medium">Password<input className="ff-input mt-2" name="password" type="password" autoComplete={mode === "login" ? "current-password" : "new-password"} minLength={mode === "login" ? 8 : 10} maxLength={128} required /></label>
    {mode === "login"&&<div className="-mt-2 text-right"><Link className="text-xs font-medium text-emerald-800" href="/forgot-password">Forgot password?</Link></div>}
    {error && <p role="alert" className="text-sm text-rose-600">{error}</p>}
    <button className="ff-button w-full py-3" disabled={busy}>{busy ? "Please wait…" : mode === "login" ? "Sign in" : "Create account"}</button>
    {googleEnabled&&<><div className="relative py-2 text-center text-xs text-slate-400"><span className="bg-white px-3">or continue with</span><div className="absolute inset-x-0 top-1/2 -z-10 border-t" /></div><button type="button" onClick={() => signIn("google", { callbackUrl: "/overview" })} className="w-full rounded-lg border border-slate-200 px-4 py-3 text-sm font-medium hover:bg-slate-50">Continue with Google</button></>}
    <p className="pt-3 text-center text-sm text-slate-500">{mode === "login" ? "New to FinanceFlow?" : "Already have an account?"} <Link className="font-semibold text-emerald-700" href={mode === "login" ? "/register" : "/login"}>{mode === "login" ? "Create an account" : "Sign in"}</Link></p>
  </form>;
}
