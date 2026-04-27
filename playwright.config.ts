import { defineConfig } from "@playwright/test";

if (!process.env.PB_URL) {
  throw new Error("PB_URL is not set. Run `npm run e2e` at the repo root.");
}

/**
 * E2E tests run against the SvelteKit dev server (port 5173).
 * PocketBase must be running first: npm run pb:start
 * Playwright starts the SvelteKit dev server automatically via webServer.
 *
 * For CI: start PocketBase before running `npx playwright test`.
 */
export default defineConfig({
  testDir: "./tests/e2e",
  timeout: 15_000,
  retries: 0,
  use: {
    baseURL: "http://localhost:5173",
    headless: true,
  },
  webServer: {
    command: "cd web && npm run dev",
    url: "http://localhost:5173",
    reuseExistingServer: true,
    timeout: 30_000,
  },
  projects: [
    {
      name: "chromium",
      use: { browserName: "chromium" },
    },
  ],
});
