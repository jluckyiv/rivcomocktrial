import { test, expect } from "@playwright/test";
import { pbCreate, pbDelete, pbList } from "./helpers/pb";
import { adminLogin } from "./helpers/auth";

const RUN_ID = Date.now().toString(36);
const tracked: { collection: string; id: string }[] = [];
const CLEANUP_ORDER = [
  "join_requests",
  "teams",
  "users",
  "schools",
  "tournaments",
] as const;

async function cleanup() {
  const failures: string[] = [];
  for (const collection of CLEANUP_ORDER) {
    const ids = tracked.filter((t) => t.collection === collection).map((t) => t.id);
    for (const id of ids) {
      try {
        await pbDelete(collection, id);
      } catch (err) {
        failures.push(`${collection}/${id}: ${String(err)}`);
      }
    }
  }
  tracked.length = 0;
  if (failures.length > 0) {
    throw new Error(`Cleanup failed:\n  - ${failures.join("\n  - ")}`);
  }
}

test.describe("Admin registrations", () => {
  test.beforeAll(async () => {
    const tournament = (await pbCreate("tournaments", {
      name: `e2e-registrations-${RUN_ID}`,
      year: 2099,
      num_preliminary_rounds: 3,
      num_elimination_rounds: 2,
      status: "registration",
    })) as { id: string };
    tracked.push({ collection: "tournaments", id: tournament.id });

    const districts = await pbList("districts", "");
    if (districts.length === 0) {
      throw new Error("No districts seeded — migrations should provide them.");
    }
    const district = districts[0] as { id: string };

    const school = (await pbCreate("schools", {
      name: `Playwright Test High School ${RUN_ID}`,
      district: district.id,
    })) as { id: string };
    tracked.push({ collection: "schools", id: school.id });

    const coach1 = (await pbCreate("users", {
      email: `playwright-coach1-${RUN_ID}@test.invalid`,
      password: "testpass123",
      passwordConfirm: "testpass123",
      name: "PW Coach One",
      role: "coach",
      status: "pending",
      school: school.id,
      team_name: `Playwright Test Team ${RUN_ID}`,
    })) as { id: string };
    tracked.push({ collection: "users", id: coach1.id });

    const teams = await pbList("teams", `coaches ~ '${coach1.id}'`);
    for (const t of teams) {
      tracked.push({ collection: "teams", id: (t as { id: string }).id });
    }
  });

  test.afterAll(cleanup);

  test("pending registrations tab shows coach rows", async ({ page }) => {
    await adminLogin(page);
    await page.goto("/admin/registrations");
    // Page is SSR — no loading spinner. Table renders immediately.
    await expect(page.getByRole("heading", { name: "Registrations" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Pending" })).toBeVisible();
  });

  test("admin can approve a pending coach", async ({ page }) => {
    const school = (await pbList(
      "schools",
      `name = 'Playwright Test High School ${RUN_ID}'`
    ))[0] as { id: string };

    const coach = (await pbCreate("users", {
      email: `playwright-coach-approve-${RUN_ID}@test.invalid`,
      password: "testpass123",
      passwordConfirm: "testpass123",
      name: "PW Coach Approve",
      role: "coach",
      status: "pending",
      school: school.id,
      team_name: `PW Approve Team ${RUN_ID}`,
    })) as { id: string };
    tracked.push({ collection: "users", id: coach.id });

    const pendingTeams = await pbList("teams", `coaches ~ '${coach.id}'`);
    for (const t of pendingTeams) {
      tracked.push({ collection: "teams", id: (t as { id: string }).id });
    }

    await adminLogin(page);
    await page.goto("/admin/registrations");

    const row = page.locator("tr").filter({ hasText: "PW Coach Approve" });
    await expect(row).toBeVisible();
    await row.getByRole("button", { name: "Approve" }).click();

    // After approval the row disappears from the Pending tab.
    await expect(row).not.toBeVisible();
  });
});
