import { test, expect } from "@playwright/test";
import { adminLogin } from "./helpers/auth";

test.describe("Admin auth", () => {
  test("login redirects to /admin dashboard", async ({ page }) => {
    await adminLogin(page);
    await expect(page).toHaveURL(/\/admin$/);
    await expect(
      page.getByRole("heading", { name: "Dashboard" })
    ).toBeVisible();
  });

  test("logout clears session and redirects to /login", async ({ page }) => {
    await adminLogin(page);
    await page.getByRole("button", { name: "Log out" }).click();
    await expect(page).toHaveURL(/\/login$/);
  });

  test("protected route redirects to /login after logout", async ({ page }) => {
    await adminLogin(page);
    await page.getByRole("button", { name: "Log out" }).click();
    await expect(page).toHaveURL(/\/login$/);

    // Navigating to a protected admin route should redirect back to login.
    await page.goto("/admin");
    await expect(page).toHaveURL(/\/login/);
  });
});
