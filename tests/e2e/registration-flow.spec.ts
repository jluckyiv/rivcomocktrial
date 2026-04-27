import { expect, test } from '@playwright/test';
import { pbCreate, pbDelete, pbList } from './helpers/pb';

// Happy-path registration flow against the isolated test PocketBase:
//   1. Coach fills out the registration form
//   2. Coach lands on /register/pending
//   3. Admin logs in, approves the registration
//   4. Coach logs in and sees their team

const TEST_PASSWORD = 'coach-test-password-123';
const RUN_ID = Date.now().toString(36);

const tracked: { collection: string; id: string }[] = [];
const CLEANUP_ORDER = ['join_requests', 'teams', 'users', 'tournaments'] as const;

test.beforeAll(async () => {
	const tournament = (await pbCreate('tournaments', {
		name: `e2e-registration-${RUN_ID}`,
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

test('happy path: register → approve → login → see team', async ({ page, context }) => {
	const adminEmail = process.env.PB_ADMIN_EMAIL!;
	const adminPassword = process.env.PB_ADMIN_PASSWORD!;

	// Step 1: coach registers ----------------------------------------------------
	await page.goto('/register/teacher-coach');

	const coachEmail = `e2e-coach-${RUN_ID}@test.invalid`;

	await page.getByLabel('First name').fill('E2E');
	await page.getByLabel('Last name').fill('Coach');
	await page.getByLabel('Email address').fill(coachEmail);

	// School select uses a Bits UI Select with a search input
	await page.getByLabel('School').click();
	await page.getByPlaceholder(/search schools/i).fill('La Sierra');
	await page.getByRole('option', { name: /La Sierra High School/i }).click();

	// Team name auto-populates from school; leave it.

	await page.getByLabel('Password', { exact: true }).fill(TEST_PASSWORD);
	await page.getByLabel('Confirm password').fill(TEST_PASSWORD);

	await page.getByRole('button', { name: 'Submit registration' }).click();

	await expect(page).toHaveURL('/register/pending');
	await expect(page.getByText(/registration submitted/i)).toBeVisible();

	// Track the user + team the registration created so afterAll cleans them up.
	const users = await pbList('users', `email = '${coachEmail}'`);
	const coachId = (users[0] as { id: string }).id;
	tracked.push({ collection: 'users', id: coachId });
	const teams = await pbList('teams', `coaches ~ '${coachId}'`);
	for (const t of teams) tracked.push({ collection: 'teams', id: (t as { id: string }).id });

	// Step 2: admin approves ----------------------------------------------------
	await page.goto('/login');
	await page.getByLabel('Email').fill(adminEmail);
	await page.getByLabel('Password').fill(adminPassword);
	await page.getByRole('button', { name: 'Sign in' }).click();

	await expect(page).toHaveURL('/admin');

	await page.goto('/admin/registrations');
	const row = page.getByRole('row').filter({ hasText: coachEmail });
	await expect(row).toBeVisible();
	await row.getByRole('button', { name: 'Approve' }).click();

	// After approval, the row should leave the Pending tab.
	await expect(page.getByRole('row').filter({ hasText: coachEmail })).toHaveCount(0);

	// Step 3: log out, log back in as the coach ---------------------------------
	// No /logout route yet (issue #159) — clear cookies directly.
	await context.clearCookies();

	await page.goto('/login');
	await page.getByLabel('Email').fill(coachEmail);
	await page.getByLabel('Password').fill(TEST_PASSWORD);
	await page.getByRole('button', { name: 'Sign in' }).click();

	await expect(page).toHaveURL('/team');

	// Step 4: coach sees their team --------------------------------------------
	await expect(page.getByRole('heading', { name: /my team/i })).toBeVisible();
	await expect(page.locator('[data-slot="card-title"]')).toContainText('La Sierra');
	await expect(page.getByText('Eligible', { exact: true })).toBeVisible();
});
