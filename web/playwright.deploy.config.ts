import { defineConfig } from '@playwright/test';

// SMOKE_BASE_URL is required — set explicitly via test:smoke:staging or
// test:smoke:prod so nothing silently runs against the wrong target.
const BASE_URL = process.env.SMOKE_BASE_URL;
if (!BASE_URL) {
	throw new Error(
		'SMOKE_BASE_URL is required. Use `npm run test:smoke:staging` or ' +
			'`npm run test:smoke:prod` instead of invoking playwright directly.'
	);
}

export default defineConfig({
	use: { baseURL: BASE_URL },
	testMatch: '**/deploy-smoke*.e2e.ts'
});
