import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = { title: "FinanceFlow — Clarity for your money", description: "A thoughtful home for your personal finances." };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
