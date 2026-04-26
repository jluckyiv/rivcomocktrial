import { defineConfig } from '@playwright/test';

const BASE_URL = process.env.SMOKE_BASE_URL ?? 'https://rivcomocktrial-staging.fly.dev';

export default defineConfig({
	use: { baseURL: BASE_URL },
	testMatch: '**/deploy-smoke.e2e.ts'
});
