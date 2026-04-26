import { test, expect } from "@playwright/test";
import { adminLogin } from "./helpers/auth";

test.describe("Admin dashboard", () => {
  test("shows navigation cards for all admin sections", async ({ page }) => {
    await adminLogin(page);
    await expect(page.getByRole("heading", { name: "Admin Dashboard" })).toBeVisible();

    // Card.Title renders as a div — match links inside main (not the NavBar).
    const main = page.locator("main");
    const expectedSections = [
      "Tournaments",
      "Teams",
      "Districts",
      "Schools",
      "Registrations",
      "Superusers",
    ];
    for (const label of expectedSections) {
      await expect(main.getByRole("link", { name: new RegExp(label) })).toBeVisible();
    }
  });
});
