import { expect, test } from '@playwright/test';

// Happy-path registration flow:
//   1. Coach fills out the registration form
//   2. Coach lands on /register/pending
//   3. Admin logs in, approves the registration
//   4. Coach logs in and sees their team
//
// Pre-conditions:
//   - PocketBase running on localhost:8090 with migrations + seeds applied
//   - A tournament exists with status="registration"
//   - TEST_ADMIN_EMAIL and TEST_ADMIN_PASSWORD env vars point to a real superuser
//
// The test self-skips if any pre-condition is missing.

const TEST_PASSWORD = 'coach-test-password-123';

test('happy path: register → approve → login → see team', async ({ page, context }) => {
	const adminEmail = process.env.TEST_ADMIN_EMAIL;
	const adminPassword = process.env.TEST_ADMIN_PASSWORD;
	test.skip(
		!adminEmail || !adminPassword,
		'Set TEST_ADMIN_EMAIL and TEST_ADMIN_PASSWORD to run this test.'
	);

	// Step 1: coach registers ----------------------------------------------------
	await page.goto('/register/teacher-coach');

	if (await page.getByText('Registration is closed').isVisible()) {
		test.skip(true, 'No tournament with status="registration". Open one in /admin/tournaments.');
	}

	const coachEmail = `e2e-coach-${Date.now()}@example.com`;

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

	// Step 2: admin approves ----------------------------------------------------
	await page.goto('/login');
	await page.getByLabel('Email').fill(adminEmail!);
	await page.getByLabel('Password').fill(adminPassword!);
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
	// Card title (team name auto-filled to school name) and description (school)
	// both contain "La Sierra". Just assert the card title slot.
	await expect(page.locator('[data-slot="card-title"]')).toContainText('La Sierra');
	// Status row shows "Active"
	await expect(page.getByText('Active', { exact: true })).toBeVisible();
});
