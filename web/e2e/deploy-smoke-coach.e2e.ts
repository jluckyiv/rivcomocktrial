import { expect, test, type Page } from '@playwright/test';

// Coach login smoke tests against a live deploy.
// Requires SMOKE_COACH_EMAIL and SMOKE_COACH_PASSWORD env vars.
// Skips cleanly when either is missing — partial credentials must not fail the run.
//
// Staging only: credentials from op://Private/rivcomocktrial-staging-smoke
// Production: no coach credentials seeded — this spec self-skips.
//
// Read-only — no record creates, patches, or deletes.

const email = process.env.SMOKE_COACH_EMAIL;
const password = process.env.SMOKE_COACH_PASSWORD;

test.skip(!email || !password, 'SMOKE_COACH_EMAIL and SMOKE_COACH_PASSWORD are required');

async function coachLogin(page: Page) {
	await page.goto('/login');
	await page.locator('input[name="email"]').fill(email!);
	await page.locator('input[name="password"]').fill(password!);
	await page.getByRole('button', { name: 'Sign in' }).click();
	await page.waitForURL(/\/team/);
}

test('coach login redirects to /team dashboard', async ({ page }) => {
	await coachLogin(page);
	await expect(page).toHaveURL(/\/team$/);
	await expect(page.getByRole('heading', { name: 'My Team' })).toBeVisible();
});

test('coach logout redirects to /login', async ({ page }) => {
	await coachLogin(page);
	await page.getByRole('button', { name: 'Log out' }).click();
	await expect(page).toHaveURL(/\/login$/);
});
