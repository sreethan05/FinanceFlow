"use client";
import { useEffect } from "react";
import { Sun } from "lucide-react";

export function ThemeToggle() {
  useEffect(() => {
    const stored = localStorage.getItem("financeflow-theme");
    const dark = stored ? stored === "dark" : window.matchMedia("(prefers-color-scheme: dark)").matches;
    document.documentElement.dataset.theme = dark ? "dark" : "light";
  }, []);
  function toggle() {
    const dark = document.documentElement.dataset.theme !== "dark";
    document.documentElement.dataset.theme = dark ? "dark" : "light";
    localStorage.setItem("financeflow-theme", dark ? "dark" : "light");
  }
  return <button type="button" onClick={toggle} aria-label="Toggle light or dark theme" title="Toggle theme" className="grid size-9 place-items-center rounded-lg border border-slate-200 text-slate-500"><Sun size={16}/></button>;
}