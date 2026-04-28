import { defineConfig } from '@playwright/test';

// PB_URL is sourced from .env.test by `npm run e2e:a11y`.
// A11Y_COACH_EMAIL / A11Y_COACH_PASSWORD are optional — the /team test
// is skipped when they are absent.
const PB_URL = process.env.PB_URL ?? 'http://localhost:28090';

export default defineConfig({
	testMatch: '**/a11y-flows.e2e.ts',
	timeout: 60_000,
	retries: 0,
	use: {
		baseURL: 'http://localhost:4173',
		headless: true
	},
	webServer: {
		command: 'npm run build && npm run preview -- --port 4173',
		url: 'http://localhost:4173',
		reuseExistingServer: false,
		timeout: 120_000,
		env: {
			PB_INTERNAL_URL: PB_URL
		}
	},
	projects: [
		{
			name: 'chromium',
			use: { browserName: 'chromium' }
		}
	]
});
