import { test, expect } from "@playwright/test";
import { pbCreate, pbDelete, pbList } from "./helpers/pb";
import { adminLogin } from "./helpers/auth";

let createdIds: { collection: string; id: string }[] = [];

async function cleanup() {
  for (const { collection, id } of createdIds.reverse()) {
    await pbDelete(collection, id);
  }
  createdIds = [];
}

let roundId: string;
let teamIds: string[] = [];

test.describe("Admin pairings", () => {
  test.beforeAll(async () => {
    // Find any existing tournament.
    const tournaments = await pbList("tournaments", "");
    if (tournaments.length === 0) {
      throw new Error("No tournaments found. Seed the dev DB first.");
    }
    const tournament = tournaments[0] as { id: string };

    // Find teams in this tournament that have a team number set.
    const teams = await pbList(
      "teams",
      `tournament = '${tournament.id}' && team_number > 0`
    );
    if (teams.length < 2) {
      throw new Error(
        "Need at least 2 teams with team_number set in the tournament."
      );
    }
    teamIds = teams.slice(0, 4).map((t) => (t as { id: string }).id);

    // Create a test round.
    const round = (await pbCreate("rounds", {
      tournament: tournament.id,
      number: 98,
      type: "preliminary",
    })) as { id: string };
    roundId = round.id;
    createdIds.push({ collection: "rounds", id: round.id });
  });

  test.afterAll(async () => {
    // Clean up any trials created during tests.
    const trials = await pbList("trials", `round = '${roundId}'`);
    for (const t of trials) {
      await pbDelete("trials", (t as { id: string }).id);
    }
    await cleanup();
  });

  // Wait for trials to finish loading (spinner gone) AND teams to populate
  // the dropdowns. Teams load in a second round-trip after the rounds response.
  async function waitForPairingsReady(page: import("@playwright/test").Page) {
    await page.locator(".loading.loading-spinner").waitFor({ state: "detached" });
    // The prosecution select starts with only the placeholder option.
    // Wait until at least one team option appears.
    await page.locator("select").first().locator("option").nth(1).waitFor({ state: "attached" });
  }

  test("page loads with Add Trial form and no trials", async ({ page }) => {
    await adminLogin(page);
    await page.goto(`/admin/pairings?round=${roundId}`);
    await waitForPairingsReady(page);

    await expect(page.getByText("Add Trial")).toBeVisible();
    await expect(page.getByText("No pairings yet for this round.")).toBeVisible();
  });

  test("form validation shows errors when teams not selected", async ({
    page,
  }) => {
    await adminLogin(page);
    await page.goto(`/admin/pairings?round=${roundId}`);
    await waitForPairingsReady(page);

    await page.getByRole("button", { name: "Save" }).click();
    await expect(page.locator(".alert.alert-error")).toBeVisible();
    await expect(
      page.getByText("Prosecution team is required")
    ).toBeVisible();
    await expect(page.getByText("Defense team is required")).toBeVisible();
  });

  test("validation error clears when prosecution team is selected", async ({
    page,
  }) => {
    await adminLogin(page);
    await page.goto(`/admin/pairings?round=${roundId}`);
    await waitForPairingsReady(page);

    await page.getByRole("button", { name: "Save" }).click();
    await expect(page.locator(".alert.alert-error")).toBeVisible();

    // Selecting a team clears errors (updateFormField clears the error slot).
    const selects = page.locator("select");
    await selects.nth(0).selectOption({ index: 1 });
    await expect(page.locator(".alert.alert-error")).not.toBeVisible();
  });

  test("can create a pairing via dropdown form", async ({ page }) => {
    await adminLogin(page);
    await page.goto(`/admin/pairings?round=${roundId}`);
    await waitForPairingsReady(page);

    const selects = page.locator("select");
    await selects.nth(0).selectOption(teamIds[0]);
    await selects.nth(1).selectOption(teamIds[1]);
    await page.getByRole("button", { name: "Save" }).click();

    // Trial row appears in the table.
    await expect(page.locator("table tbody tr")).toHaveCount(1);
    // Form resets to Creating state.
    await expect(page.getByText("Add Trial")).toBeVisible();
  });

  test("edit populates form and title changes to Edit Trial", async ({
    page,
  }) => {
    await adminLogin(page);
    await page.goto(`/admin/pairings?round=${roundId}`);
    await waitForPairingsReady(page);

    // There should be one trial from the previous test (or create one).
    const rows = page.locator("table tbody tr");
    if ((await rows.count()) === 0) {
      const selects = page.locator("select");
      await selects.nth(0).selectOption(teamIds[0]);
      await selects.nth(1).selectOption(teamIds[1]);
      await page.getByRole("button", { name: "Save" }).click();
      await expect(rows).toHaveCount(1);
    }

    await rows.first().getByRole("button", { name: "Edit" }).click();
    await expect(page.getByText("Edit Trial")).toBeVisible();
    // Cancel button appears when editing.
    await expect(page.getByRole("button", { name: "Cancel" })).toBeVisible();
  });

  test("cancel edit resets form to Add Trial", async ({ page }) => {
    await adminLogin(page);
    await page.goto(`/admin/pairings?round=${roundId}`);
    await waitForPairingsReady(page);

    const rows = page.locator("table tbody tr");
    if ((await rows.count()) === 0) {
      const selects = page.locator("select");
      await selects.nth(0).selectOption(teamIds[0]);
      await selects.nth(1).selectOption(teamIds[1]);
      await page.getByRole("button", { name: "Save" }).click();
      await expect(rows).toHaveCount(1);
    }

    await rows.first().getByRole("button", { name: "Edit" }).click();
    await expect(page.getByText("Edit Trial")).toBeVisible();

    await page.getByRole("button", { name: "Cancel" }).click();
    await expect(page.getByText("Add Trial")).toBeVisible();
    await expect(
      page.getByRole("button", { name: "Cancel" })
    ).not.toBeVisible();
  });

  test("can delete a pairing", async ({ page }) => {
    await adminLogin(page);
    await page.goto(`/admin/pairings?round=${roundId}`);
    await waitForPairingsReady(page);

    const rows = page.locator("table tbody tr");
    const before = await rows.count();

    // Ensure there is at least one trial.
    if (before === 0) {
      const selects = page.locator("select");
      await selects.nth(0).selectOption(teamIds[0]);
      await selects.nth(1).selectOption(teamIds[1]);
      await page.getByRole("button", { name: "Save" }).click();
      await expect(rows).toHaveCount(1);
    }

    const countBefore = await rows.count();
    await rows.first().getByRole("button", { name: "Delete" }).click();
    await expect(rows).toHaveCount(countBefore - 1);
  });

  test("switches to bulk text mode and shows textarea", async ({ page }) => {
    await adminLogin(page);
    await page.goto(`/admin/pairings?round=${roundId}`);
    await waitForPairingsReady(page);

    await page.getByText("Bulk Text").click();
    await expect(page.locator("textarea")).toBeVisible();
    await expect(page.getByRole("button", { name: "Preview" })).toBeVisible();
  });

  test("bulk preview shows parsed pairings table", async ({ page }) => {
    await adminLogin(page);
    await page.goto(`/admin/pairings?round=${roundId}`);
    await waitForPairingsReady(page);

    // Get the team numbers for bulk text input.
    const teamRecords = await pbList(
      "teams",
      `id = '${teamIds[0]}' || id = '${teamIds[1]}'`
    );
    const nums = teamRecords.map(
      (t) => (t as { team_number: number }).team_number
    );
    if (nums.length < 2) {
      test.skip();
      return;
    }

    await page.getByText("Bulk Text").click();
    await page.locator("textarea").fill(`${nums[0]} v ${nums[1]}`);
    await page.getByRole("button", { name: "Preview" }).click();

    await expect(page.getByText("Preview")).toBeVisible();
    await expect(page.getByRole("button", { name: "Create All" })).toBeVisible();
    await expect(page.getByRole("button", { name: "Cancel" })).toBeVisible();
  });

  test("cancel bulk preview returns to text entry", async ({ page }) => {
    await adminLogin(page);
    await page.goto(`/admin/pairings?round=${roundId}`);
    await waitForPairingsReady(page);

    const teamRecords = await pbList(
      "teams",
      `id = '${teamIds[0]}' || id = '${teamIds[1]}'`
    );
    const nums = teamRecords.map(
      (t) => (t as { team_number: number }).team_number
    );
    if (nums.length < 2) {
      test.skip();
      return;
    }

    await page.getByText("Bulk Text").click();
    await page.locator("textarea").fill(`${nums[0]} v ${nums[1]}`);
    await page.getByRole("button", { name: "Preview" }).click();
    await expect(page.getByRole("button", { name: "Create All" })).toBeVisible();

    await page.getByRole("button", { name: "Cancel" }).click();

    // Back to editing: textarea visible, text preserved, no Create All button.
    await expect(page.locator("textarea")).toBeVisible();
    await expect(page.locator("textarea")).toHaveValue(`${nums[0]} v ${nums[1]}`);
    await expect(
      page.getByRole("button", { name: "Create All" })
    ).not.toBeVisible();
  });

  test("bulk confirm creates trials", async ({ page }) => {
    await adminLogin(page);
    await page.goto(`/admin/pairings?round=${roundId}`);
    await waitForPairingsReady(page);

    // Ensure round is clean before this test.
    const existing = await pbList("trials", `round = '${roundId}'`);
    for (const t of existing) {
      await pbDelete("trials", (t as { id: string }).id);
    }
    await page.reload();
    await waitForPairingsReady(page);

    const teamRecords = await pbList(
      "teams",
      `id = '${teamIds[0]}' || id = '${teamIds[1]}'`
    );
    const nums = teamRecords.map(
      (t) => (t as { team_number: number }).team_number
    );
    if (nums.length < 2) {
      test.skip();
      return;
    }

    await page.getByText("Bulk Text").click();
    await page.locator("textarea").fill(`${nums[0]} v ${nums[1]}`);
    await page.getByRole("button", { name: "Preview" }).click();
    await page.getByRole("button", { name: "Create All" }).click();

    // After confirm, bulk state resets to idle and trial appears in the table.
    await expect(page.locator("table tbody tr")).toHaveCount(1, {
      timeout: 5000,
    });
  });
});
