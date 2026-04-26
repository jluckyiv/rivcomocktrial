import type { Page } from "@playwright/test";

export async function adminLogin(page: Page) {
  await page.goto("/login");
  // shadcn Label+Input are siblings, not nested — use name attribute.
  await page.locator('input[name="email"]').fill(process.env.PB_ADMIN_EMAIL!);
  await page.locator('input[name="password"]').fill(
    process.env.PB_ADMIN_PASSWORD!
  );
  await page.getByRole("button", { name: "Sign in" }).click();
  await page.waitForURL(/\/admin/);
}
