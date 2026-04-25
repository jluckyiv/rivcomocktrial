import type { Page } from "@playwright/test";

export async function adminLogin(page: Page) {
  await page.goto("/admin/login");
  // Email input is the first input inside a label containing "Email".
  await page.locator('label:has-text("Email") input').fill(
    process.env.PB_ADMIN_EMAIL!
  );
  await page.locator('input[type="password"]').fill(
    process.env.PB_ADMIN_PASSWORD!
  );
  await page.getByRole("button", { name: "Login" }).click();
  await page.locator("text=RCMT Admin").waitFor();
}
