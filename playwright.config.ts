import { defineConfig } from "@playwright/test";

/**
 * Local e2e tests against the isolated test PocketBase (port 28090)
 * fronted by a SvelteKit preview build on port 4173.
 *
 * Run via `npm run e2e` at the repo root, which:
 *   1. starts the test container (`pb:test:up`)
 *   2. sources `.env.test` for PB_URL + admin credentials
 *   3. invokes Playwright
 *
 * The preview server inherits PB_INTERNAL_URL from PB_URL so SvelteKit
 * SSR talks to the test container, not the dev container.
 */
export default defineConfig({
  testDir: "./tests/e2e",
  timeout: 30_000,
  retries: 0,
  workers: 1,
  use: {
    baseURL: "http://localhost:4173",
    headless: true,
  },
  webServer: {
    command: "cd web && npm run build && npm run preview -- --port 4173",
    url: "http://localhost:4173",
    reuseExistingServer: false,
    timeout: 120_000,
    env: {
      PB_INTERNAL_URL: process.env.PB_URL ?? "",
    },
  },
  projects: [
    {
      name: "chromium",
      use: { browserName: "chromium" },
    },
  ],
});
