import { expect, test, type Page } from '@playwright/test';

// Admin login smoke tests against a live deploy.
// Requires SMOKE_ADMIN_EMAIL and SMOKE_ADMIN_PASSWORD env vars.
// Skips cleanly when either is missing — partial credentials must not fail the run.
//
// Staging: credentials from op://Private/rivcomocktrial-staging-smoke
// Production: credentials from op://Private/rivcomocktrial (bootstrap superuser)
//
// Read-only — no record creates, patches, or deletes.

const email = process.env.SMOKE_ADMIN_EMAIL;
const password = process.env.SMOKE_ADMIN_PASSWORD;

test.skip(!email || !password, 'SMOKE_ADMIN_EMAIL and SMOKE_ADMIN_PASSWORD are required');

async function adminLogin(page: Page) {
	await page.goto('/login');
	await page.locator('input[name="email"]').fill(email!);
	await page.locator('input[name="password"]').fill(password!);
	await page.getByRole('button', { name: 'Sign in' }).click();
	await page.waitForURL(/\/admin/);
}

test('admin login redirects to /admin dashboard', async ({ page }) => {
	await adminLogin(page);
	await expect(page).toHaveURL(/\/admin$/);
	await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
});

test('admin logout redirects to /login', async ({ page }) => {
	await adminLogin(page);
	await page.getByRole('button', { name: 'Log out' }).click();
	await expect(page).toHaveURL(/\/login$/);
});

test('protected /admin redirects to /login after logout', async ({ page }) => {
	await adminLogin(page);
	await page.getByRole('button', { name: 'Log out' }).click();
	await expect(page).toHaveURL(/\/login$/);
	await page.goto('/admin');
	await expect(page).toHaveURL(/\/login/);
});
