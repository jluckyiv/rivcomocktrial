import { expect, test } from '@playwright/test';

// Read-only smoke tests against a live deploy. Run with:
//   SMOKE_BASE_URL=https://rivcomocktrial-staging.fly.dev \
//     npx playwright test --config playwright.deploy.config.ts
//
// SMOKE_BASE_URL defaults to staging (see playwright.deploy.config.ts).
// No mutations — these can run against production.

test('GET / returns SvelteKit HTML', async ({ page }) => {
	const response = await page.goto('/');
	expect(response?.ok()).toBeTruthy();
	await expect(page.locator('body')).toBeVisible();
});

test('GET /_/ returns the PocketBase admin SPA', async ({ page }) => {
	await page.goto('/_/');
	await expect(page.getByText(/Superuser login/i)).toBeVisible({ timeout: 10000 });
});

test('GET /login renders the SvelteKit login form', async ({ page }) => {
	await page.goto('/login');
	await expect(page.getByRole('button', { name: /sign in/i })).toBeVisible();
});

test('GET /register/teacher-coach renders form or closed card', async ({ page }) => {
	await page.goto('/register/teacher-coach');
	// Either the registration form is shown, or the "Registration is closed"
	// card is — both are valid live states. Just assert page rendered.
	const submit = page.getByRole('button', { name: /submit registration/i });
	const closed = page.getByText(/registration is closed/i);
	await expect(submit.or(closed)).toBeVisible();
});

test('SSE realtime emits PB_CONNECT through Caddy', async ({ page, baseURL }) => {
	await page.goto('/');
	const event = await page.evaluate(async (url) => {
		return new Promise<{ clientId: string }>((resolve, reject) => {
			const es = new EventSource(`${url}/api/realtime`);
			const timeout = setTimeout(() => {
				es.close();
				reject(new Error('No PB_CONNECT within 5s'));
			}, 5000);
			es.addEventListener('PB_CONNECT', (e) => {
				clearTimeout(timeout);
				es.close();
				resolve(JSON.parse((e as MessageEvent).data));
			});
		});
	}, baseURL);
	expect(event.clientId).toBeTruthy();
});

test('Auth cookie is HttpOnly + Secure on response from /', async ({ request, baseURL }) => {
	const response = await request.get('/');
	expect(response.ok(), `against ${baseURL}/`).toBeTruthy();
	const setCookie = response.headers()['set-cookie'] ?? '';
	expect(setCookie.toLowerCase()).toContain('httponly');
	expect(setCookie.toLowerCase()).toContain('secure');
});
