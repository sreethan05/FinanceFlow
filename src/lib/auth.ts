import NextAuth, { getServerSession, type NextAuthOptions } from "next-auth";
import { PrismaAdapter } from "@next-auth/prisma-adapter";
import CredentialsProvider from "next-auth/providers/credentials";
import GoogleProvider from "next-auth/providers/google";
import bcrypt from "bcryptjs";
import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { rateLimit } from "@/lib/rate-limit";

const credentialsSchema = z.object({ email: z.string().email(), password: z.string().min(8).max(128) });
const providers: NextAuthOptions["providers"] = [CredentialsProvider({
  credentials: { email: { label: "Email", type: "email" }, password: { label: "Password", type: "password" } },
  async authorize(raw, request) {
    const forwarded = request.headers?.["x-forwarded-for"]; const ip = Array.isArray(forwarded) ? forwarded[0] : forwarded;
    const limited = await rateLimit(new Request("http://localhost", { headers: ip ? { "x-forwarded-for": ip } : {} }), "login", 8, 900);
    if (!limited) return null;
    const parsed = credentialsSchema.safeParse(raw); if (!parsed.success) return null;
    const user = await prisma.user.findUnique({ where: { email: parsed.data.email.toLowerCase() } });
    if (!user?.passwordHash || !(await bcrypt.compare(parsed.data.password, user.passwordHash))) return null;
    if (process.env.REQUIRE_EMAIL_VERIFICATION === "true" && !user.emailVerified) return null;
    return { id: user.id, name: user.name, email: user.email };
  },
})];
if (process.env.GOOGLE_CLIENT_ID && process.env.GOOGLE_CLIENT_SECRET) providers.push(GoogleProvider({ clientId: process.env.GOOGLE_CLIENT_ID, clientSecret: process.env.GOOGLE_CLIENT_SECRET }));

export const authOptions: NextAuthOptions = {
  adapter: PrismaAdapter(prisma), secret: process.env.NEXTAUTH_SECRET ?? process.env.AUTH_SECRET, providers, session: { strategy: "jwt" }, pages: { signIn: "/login" },
  callbacks: {
    async jwt({ token, user }) {
      if (user?.id) { const account = await prisma.user.findUnique({ where: { id: user.id }, select: { sessionVersion: true } }); token.userId = user.id; token.sessionVersion = account?.sessionVersion ?? 0; }
      else if (token.userId) { const account = await prisma.user.findUnique({ where: { id: token.userId }, select: { sessionVersion: true } }); if (!account || account.sessionVersion !== token.sessionVersion) token.userId = ""; }
      return token;
    },
    async session({ session, token }) { if (session.user) session.user.id = token.userId ?? ""; return session; },
  },
};
export const auth = () => getServerSession(authOptions);
export const authHandler = NextAuth(authOptions);
