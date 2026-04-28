import { expect, test } from '@playwright/test';
import { pbCreate, pbDelete, pbList } from './helpers/pb';

// Join-existing flow:
//   1. First coach registers (creates team)
//   2. Second coach submits same name+school → collision dialog appears
//   3. Second coach clicks "Request to join" → lands on /register/pending
//   4. A pending join_requests row exists for the second coach

const TEST_PASSWORD = 'coach-test-password-123';
const RUN_ID = Date.now().toString(36);

const tracked: { collection: string; id: string }[] = [];
const CLEANUP_ORDER = ['join_requests', 'teams', 'users', 'tournaments'] as const;

test.beforeAll(async () => {
	const tournament = (await pbCreate('tournaments', {
		name: `e2e-join-existing-${RUN_ID}`,
		year: 2099,
		num_preliminary_rounds: 3,
		num_elimination_rounds: 2,
		status: 'registration'
	})) as { id: string };
	tracked.push({ collection: 'tournaments', id: tournament.id });
});

test.afterAll(async () => {
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
		throw new Error(`Cleanup failed:\n  - ${failures.join('\n  - ')}`);
	}
});

test('join-existing: collision dialog → Request to join → pending join_requests row', async ({
	page
}) => {
	const TEAM_NAME = `e2e-join-team-${RUN_ID}`;

	// Step 1: first coach registers, creating the team ---------------------------
	await page.goto('/register/teacher-coach');

	const coachAEmail = `e2e-join-a-${RUN_ID}@test.invalid`;

	await page.getByLabel('First name').fill('Coach');
	await page.getByLabel('Last name').fill('Alpha');
	await page.getByLabel('Email address').fill(coachAEmail);

	await page.getByLabel('School').click();
	await page.getByPlaceholder(/search schools/i).fill('La Sierra');
	await page.getByRole('option', { name: /La Sierra High School/i }).click();

	// Override auto-populated name so parallel test runs don't collide.
	await page.getByLabel('Team name').fill(TEAM_NAME);

	await page.getByLabel('Password', { exact: true }).fill(TEST_PASSWORD);
	await page.getByLabel('Confirm password').fill(TEST_PASSWORD);

	await page.getByRole('button', { name: 'Submit registration' }).click();
	await expect(page).toHaveURL('/register/pending');

	const usersA = await pbList('users', `email = '${coachAEmail}'`);
	const coachAId = (usersA[0] as { id: string }).id;
	tracked.push({ collection: 'users', id: coachAId });

	const teamsA = await pbList('teams', `coaches ~ '${coachAId}'`);
	for (const t of teamsA) tracked.push({ collection: 'teams', id: (t as { id: string }).id });

	// Step 2: second coach submits the same team name + school -----------------
	await page.goto('/register/teacher-coach');

	const coachBEmail = `e2e-join-b-${RUN_ID}@test.invalid`;

	await page.getByLabel('First name').fill('Coach');
	await page.getByLabel('Last name').fill('Beta');
	await page.getByLabel('Email address').fill(coachBEmail);

	await page.getByLabel('School').click();
	await page.getByPlaceholder(/search schools/i).fill('La Sierra');
	await page.getByRole('option', { name: /La Sierra High School/i }).click();

	// Use the same unique team name as coach A to trigger the collision.
	await page.getByLabel('Team name').fill(TEAM_NAME);

	await page.getByLabel('Password', { exact: true }).fill(TEST_PASSWORD);
	await page.getByLabel('Confirm password').fill(TEST_PASSWORD);

	await page.getByRole('button', { name: 'Submit registration' }).click();

	// Step 3: collision dialog appears -------------------------------------------
	await expect(page.getByRole('alertdialog')).toBeVisible();
	await expect(page.getByText(/team already exists/i)).toBeVisible();

	// Step 4: confirm join -------------------------------------------------------
	await page.getByRole('button', { name: 'Request to join' }).click();

	// Regression guards: password fields must survive the failed first submit
	// (update({ reset: false })), and the team name must not be overwritten by
	// the school auto-populate (prevAutoName not set in restore effect).
	await expect(page.getByLabel('Password', { exact: true })).toHaveValue(TEST_PASSWORD);
	await expect(page.getByLabel('Confirm password')).toHaveValue(TEST_PASSWORD);
	await expect(page.getByLabel('Team name')).toHaveValue(TEAM_NAME);

	await expect(page).toHaveURL('/register/pending');

	// Step 5: verify join_requests row -------------------------------------------
	const usersB = await pbList('users', `email = '${coachBEmail}'`);
	const coachBId = (usersB[0] as { id: string }).id;
	tracked.push({ collection: 'users', id: coachBId });

	const joinRequests = await pbList('join_requests', `user = '${coachBId}'`);
	expect(joinRequests).toHaveLength(1);
	const jr = joinRequests[0] as { id: string; status: string };
	tracked.push({ collection: 'join_requests', id: jr.id });
	expect(jr.status).toBe('pending');
});

test('join-existing: dismiss dialog → can choose different name', async ({ page }) => {
	// This test verifies the "Choose different name" path clears the dialog.
	// It does not complete a registration to keep scope minimal.

	const DISMISS_TEAM_NAME = `e2e-dismiss-team-${RUN_ID}`;

	// Seed a first coach so a collision exists.
	await page.goto('/register/teacher-coach');

	const coachCEmail = `e2e-join-c-${RUN_ID}@test.invalid`;
	await page.getByLabel('First name').fill('Coach');
	await page.getByLabel('Last name').fill('Gamma');
	await page.getByLabel('Email address').fill(coachCEmail);
	await page.getByLabel('School').click();
	await page.getByPlaceholder(/search schools/i).fill('La Sierra');
	await page.getByRole('option', { name: /La Sierra High School/i }).click();
	await page.getByLabel('Team name').fill(DISMISS_TEAM_NAME);
	await page.getByLabel('Password', { exact: true }).fill(TEST_PASSWORD);
	await page.getByLabel('Confirm password').fill(TEST_PASSWORD);
	await page.getByRole('button', { name: 'Submit registration' }).click();
	await expect(page).toHaveURL('/register/pending');

	const usersC = await pbList('users', `email = '${coachCEmail}'`);
	const coachCId = (usersC[0] as { id: string }).id;
	tracked.push({ collection: 'users', id: coachCId });
	const teamsC = await pbList('teams', `coaches ~ '${coachCId}'`);
	for (const t of teamsC) tracked.push({ collection: 'teams', id: (t as { id: string }).id });

	// Trigger collision by submitting the same unique team name.
	await page.goto('/register/teacher-coach');
	await page.getByLabel('First name').fill('Coach');
	await page.getByLabel('Last name').fill('Delta');
	await page.getByLabel('Email address').fill(`e2e-join-d-${RUN_ID}@test.invalid`);
	await page.getByLabel('School').click();
	await page.getByPlaceholder(/search schools/i).fill('La Sierra');
	await page.getByRole('option', { name: /La Sierra High School/i }).click();
	await page.getByLabel('Team name').fill(DISMISS_TEAM_NAME);
	await page.getByLabel('Password', { exact: true }).fill(TEST_PASSWORD);
	await page.getByLabel('Confirm password').fill(TEST_PASSWORD);
	await page.getByRole('button', { name: 'Submit registration' }).click();

	await expect(page.getByRole('alertdialog')).toBeVisible();

	// Dismiss
	await page.getByRole('button', { name: 'Choose different name' }).click();
	await expect(page.getByRole('alertdialog')).not.toBeVisible();

	// Form is still on the page with values intact
	await expect(page.getByLabel('Email address')).toHaveValue(`e2e-join-d-${RUN_ID}@test.invalid`);
});
