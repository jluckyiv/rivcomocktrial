import type { Page } from "@playwright/test";

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is not set. Run \`npm run e2e\` at the repo root.`);
  return value;
}

const ADMIN_EMAIL = requireEnv("PB_ADMIN_EMAIL");
const ADMIN_PASSWORD = requireEnv("PB_ADMIN_PASSWORD");

export async function adminLogin(page: Page) {
  await page.goto("/login");
  // shadcn Label+Input are siblings, not nested — use name attribute.
  await page.locator('input[name="email"]').fill(ADMIN_EMAIL);
  await page.locator('input[name="password"]').fill(ADMIN_PASSWORD);
  await page.getByRole("button", { name: "Sign in" }).click();
  await page.waitForURL(/\/admin/);
}
