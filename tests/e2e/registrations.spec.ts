import { test, expect } from "@playwright/test";
import { pbCreate, pbPatch, pbDelete, pbList } from "./helpers/pb";
import { adminLogin } from "./helpers/auth";

let createdIds: { collection: string; id: string }[] = [];

async function cleanup() {
  for (const { collection, id } of createdIds.reverse()) {
    await pbDelete(collection, id);
  }
  createdIds = [];
}

test.describe("Admin registrations", () => {
  test.beforeAll(async () => {
    const tournaments = await pbList("tournaments", "status = 'registration'");
    if (tournaments.length === 0) {
      throw new Error(
        "No registration-status tournament found. Seed the dev DB first."
      );
    }

    // district is a relation — look up a real one.
    const districts = await pbList("districts", "");
    if (districts.length === 0) {
      throw new Error("No districts found. Seed the dev DB first.");
    }
    const district = districts[0] as { id: string };

    const school = (await pbCreate("schools", {
      name: "Playwright Test High School",
      district: district.id,
    })) as { id: string };
    createdIds.push({ collection: "schools", id: school.id });

    const coach1 = (await pbCreate("users", {
      email: "playwright-coach1@test.invalid",
      password: "testpass123",
      passwordConfirm: "testpass123",
      name: "PW Coach One",
      role: "coach",
      status: "pending",
      school: school.id,
      team_name: "Playwright Test High School",
    })) as { id: string };
    createdIds.push({ collection: "users", id: coach1.id });

    await pbPatch("users", coach1.id, { status: "approved" });

    const teams = await pbList("teams", `coach = '${coach1.id}'`);
    for (const t of teams) {
      createdIds.push({ collection: "teams", id: (t as { id: string }).id });
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
    const districts = await pbList("districts", "");
    const district = districts[0] as { id: string };

    const school = (await pbList(
      "schools",
      "name = 'Playwright Test High School'"
    ))[0] as { id: string };

    const coach = (await pbCreate("users", {
      email: "playwright-coach-approve@test.invalid",
      password: "testpass123",
      passwordConfirm: "testpass123",
      name: "PW Coach Approve",
      role: "coach",
      status: "pending",
      school: school.id,
      team_name: "PW Approve Team",
    })) as { id: string };
    createdIds.push({ collection: "users", id: coach.id });

    const pendingTeams = await pbList("teams", `coach = '${coach.id}'`);
    for (const t of pendingTeams) {
      createdIds.push({ collection: "teams", id: (t as { id: string }).id });
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
