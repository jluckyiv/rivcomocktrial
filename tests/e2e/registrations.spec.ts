import { test, expect } from "@playwright/test";
import { pbCreate, pbPatch, pbDelete, pbList } from "./helpers/pb";

/**
 * IDs of records created for each test run, collected for cleanup.
 */
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
  // Wait for the admin nav (only present after successful login).
  await page.locator("text=RCMT Admin").waitFor();
}

test.describe("Admin registrations", () => {
  test.beforeAll(async () => {
    // Find the active registration tournament.
    const tournaments = await pbList(
      "tournaments",
      "status = 'registration'"
    );
    if (tournaments.length === 0) {
      throw new Error(
        "No registration-status tournament found. Seed the dev DB first."
      );
    }
    const tournament = tournaments[0] as { id: string };

    // Create a test school.
    const school = await pbCreate("schools", {
      name: "Playwright Test High School",
      district: "Test District",
    }) as { id: string };
    createdIds.push({ collection: "schools", id: school.id });

    // Create first coach (will be approved → active team).
    const coach1 = await pbCreate("users", {
      email: "playwright-coach1@test.invalid",
      password: "testpass123",
      passwordConfirm: "testpass123",
      name: "PW Coach One",
      role: "coach",
      status: "pending",
      school: school.id,
      team_name: "Playwright Test High School",
    }) as { id: string };
    createdIds.push({ collection: "users", id: coach1.id });

    // Approving the coach triggers the PB hook that creates the active team.
    await pbPatch("users", coach1.id, { status: "approved" });

    // Collect the team the hook created so we can clean it up.
    const teams = await pbList("teams", `coach = '${coach1.id}'`);
    for (const t of teams) {
      createdIds.push({ collection: "teams", id: (t as { id: string }).id });
    }

    // Create second coach from the same school (pending — no team yet).
    const coach2 = await pbCreate("users", {
      email: "playwright-coach2@test.invalid",
      password: "testpass123",
      passwordConfirm: "testpass123",
      name: "PW Coach Two",
      role: "coach",
      status: "pending",
      school: school.id,
      team_name: "Playwright Test High School B",
    }) as { id: string };
    createdIds.push({ collection: "users", id: coach2.id });

    // Collect the pending team the hook created for coach2.
    const pendingTeams = await pbList("teams", `coach = '${coach2.id}'`);
    for (const t of pendingTeams) {
      createdIds.push({ collection: "teams", id: (t as { id: string }).id });
    }
  });

  test.afterAll(cleanup);

  test("pending coach from same school shows second-team badge", async ({
    page,
  }) => {
    await adminLogin(page);
    await page.goto("/admin/registrations");
    await page.locator(".loading-spinner").waitFor({ state: "detached" });

    // Find the row for PW Coach Two.
    const row = page.locator("tr").filter({ hasText: "PW Coach Two" });
    await expect(row).toBeVisible();

    // The "2nd Team" badge should appear in their row.
    await expect(row.getByText("2nd Team")).toBeVisible();

    // The note should name the existing team and coach.
    await expect(
      row.getByText(/Same school as: Playwright Test High School/)
    ).toBeVisible();
    await expect(row.getByText(/coach: PW Coach One/)).toBeVisible();
  });

  test("first coach from a school shows no second-team badge", async ({
    page,
  }) => {
    await adminLogin(page);
    await page.goto("/admin/registrations");
    await page.locator(".loading-spinner").waitFor({ state: "detached" });

    const row = page
      .locator("tr")
      .filter({ hasText: "playwright-coach1@test.invalid" });
    await expect(row).toBeVisible();
    await expect(row.getByText("2nd Team")).not.toBeVisible();
  });

  test("admin can approve a pending coach", async ({ page }) => {
    // Create a throwaway pending coach to approve without affecting other tests.
    const schools = await pbList(
      "schools",
      "name = 'Playwright Test High School'"
    );
    const school = schools[0] as { id: string };

    const coach3 = await pbCreate("users", {
      email: "playwright-coach3@test.invalid",
      password: "testpass123",
      passwordConfirm: "testpass123",
      name: "PW Coach Three",
      role: "coach",
      status: "pending",
      school: school.id,
      team_name: "Playwright Test High School C",
    }) as { id: string };
    createdIds.push({ collection: "users", id: coach3.id });

    const pendingTeams = await pbList("teams", `coach = '${coach3.id}'`);
    for (const t of pendingTeams) {
      createdIds.push({ collection: "teams", id: (t as { id: string }).id });
    }

    await adminLogin(page);
    await page.goto("/admin/registrations");
    await page.locator(".loading-spinner").waitFor({ state: "detached" });

    const row = page.locator("tr").filter({ hasText: "PW Coach Three" });
    await row.getByRole("button", { name: "Approve" }).click();

    // Row status badge updates to Approved after approval.
    await expect(row.getByText("Approved")).toBeVisible();
  });
});
