import { loadEnvConfig } from "@next/env";
import { defineConfig } from "@playwright/test";

loadEnvConfig(process.cwd());
const baseURL = "http://127.0.0.1:3001";

export default defineConfig({
  testDir: "./tests/browser",
  fullyParallel: false,
  workers: 1,
  reporter: "list",
  timeout: 45_000,
  use: { baseURL, browserName: "chromium", headless: true, launchOptions: { channel: "chrome" } },
  webServer: {
    command: "npm run dev -- --port 3001",
    url: `${baseURL}/api/health`,
    reuseExistingServer: false,
    timeout: 120_000,
    env: { ...process.env, AUTH_URL: baseURL, NEXTAUTH_URL: baseURL },
    stdout: "pipe",
    stderr: "pipe",
  },
});