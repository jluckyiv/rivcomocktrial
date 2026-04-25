import { defineConfig } from "@playwright/test";

/**
 * E2E tests run against the production build served by PocketBase.
 * PocketBase must be running: npm run pb:start
 * Frontend must be built and deployed into the container:
 *   npm run fe:build && npm run pb:deploy-frontend
 *
 * For CI: ensure PocketBase is up and the build is in pb_public before
 * running `npx playwright test`.
 */
export default defineConfig({
  testDir: "./tests/e2e",
  timeout: 15_000,
  retries: 0,
  use: {
    baseURL: "http://localhost:8090",
    headless: true,
  },
  projects: [
    {
      name: "chromium",
      use: { browserName: "chromium" },
    },
  ],
});
