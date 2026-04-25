import { test, expect } from "@playwright/test";
import { pbCreate, pbPatch, pbDelete, pbList } from "./helpers/pb";

let createdIds: { collection: string; id: string }[] = [];

async function cleanup() {
  for (const { collection, id } of createdIds.reverse()) {
    await pbDelete(collection, id);
  }
  createdIds = [];
}

async function adminLogin(page: import("@playwright/test").Page) {
  await page.goto("/admin/login");
  await page.fill(
    'input[placeholder="admin@example.com"]',
    process.env.PB_ADMIN_EMAIL!
  );
  await page.fill('input[type="password"]', process.env.PB_ADMIN_PASSWORD!);
  await page.getByRole("button", { name: "Login" }).click();
  // Wait for the admin nav — only present after successful login.
  await page.locator("text=RCMT Admin").waitFor();
}

test.describe("Admin dashboard", () => {
  test.beforeAll(async () => {
    // Ensure there is a registration-status tournament for the dashboard tests.
    const existing = await pbList(
      "tournaments",
      "status = 'registration'"
    );
    if (existing.length === 0) {
      throw new Error(
        "No registration-status tournament found. Seed the dev DB first."
      );
    }
  });

  test.afterAll(cleanup);

  test("admin login redirects to /admin dashboard", async ({ page }) => {
    await adminLogin(page);
    // After login the URL should be /admin, not /admin/tournaments.
    await expect(page).toHaveURL(/\/admin$/);
    // The page title should be Dashboard.
    await expect(page.getByRole("heading", { name: "Dashboard" })).toBeVisible();
  });

  test("registration-phase dashboard shows stat cards", async ({ page }) => {
    await adminLogin(page);
    await page.goto("/admin");
    await page.locator(".loading-spinner").waitFor({ state: "detached" });

    // Tournament badge should read "Registration".
    await expect(page.getByText("Registration")).toBeVisible();

    // The three stat card labels should be visible.
    await expect(page.getByText("Pending Approvals")).toBeVisible();
    await expect(page.getByText("Active Teams")).toBeVisible();
    await expect(page.getByText("Pending Withdrawals")).toBeVisible();

    // The "View Registrations" link should be present.
    await expect(
      page.getByRole("link", { name: "View Registrations" })
    ).toBeVisible();
  });

  test("pending approval count increments when a coach registers", async ({
    page,
  }) => {
    // Find the registration tournament and a school to use.
    const schools = await pbList("schools", "");
    if (schools.length === 0) {
      throw new Error("No schools found. Seed the dev DB first.");
    }
    const school = schools[0] as { id: string };

    // Record the current pending count before adding a coach.
    await adminLogin(page);
    await page.goto("/admin");
    await page.locator(".loading-spinner").waitFor({ state: "detached" });

    const statEl = page
      .locator(".stat")
      .filter({ hasText: "Pending Approvals" })
      .locator(".stat-value");
    const before = parseInt((await statEl.textContent()) ?? "0", 10);

    // Create a pending coach via the API.
    const coach = await pbCreate("users", {
      email: "playwright-dash-coach@test.invalid",
      password: "testpass123",
      passwordConfirm: "testpass123",
      name: "PW Dash Coach",
      role: "coach",
      status: "pending",
      school: school.id,
      team_name: "PW Dash Team",
    }) as { id: string };
    createdIds.push({ collection: "users", id: coach.id });

    // Also clean up the team the hook created.
    const teams = await pbList("teams", `coach = '${coach.id}'`);
    for (const t of teams) {
      createdIds.push({ collection: "teams", id: (t as { id: string }).id });
    }

    // Reload the dashboard and check the count went up by 1.
    await page.goto("/admin");
    await page.locator(".loading-spinner").waitFor({ state: "detached" });

    const after = parseInt(
      (await page
        .locator(".stat")
        .filter({ hasText: "Pending Approvals" })
        .locator(".stat-value")
        .textContent()) ?? "0",
      10
    );

    expect(after).toBe(before + 1);
  });
});
