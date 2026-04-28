/**
 * WCAG 2.2 AA accessibility audit via axe-core.
 * Driven by the /audit-a11y Claude Code skill — not a CI gate.
 *
 * Run via the skill or:
 *   npm run e2e:a11y       (from repo root, sources .env.test)
 *
 * Results are written to web/a11y-results.json for the skill to read.
 *
 * /team requires an approved coach account. Set A11Y_COACH_EMAIL and
 * A11Y_COACH_PASSWORD to include it; otherwise the test is skipped.
 */

import { test, type Page } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { writeFileSync } from 'fs';
import type { Result } from 'axe-core';

interface RouteResult {
	route: string;
	violations: Result[];
}

const results: RouteResult[] = [];

const ADMIN_EMAIL = process.env.PB_ADMIN_EMAIL ?? '';
const ADMIN_PASSWORD = process.env.PB_ADMIN_PASSWORD ?? '';
const COACH_EMAIL = process.env.A11Y_COACH_EMAIL ?? '';
const COACH_PASSWORD = process.env.A11Y_COACH_PASSWORD ?? '';

async function loginAsAdmin(page: Page): Promise<void> {
	await page.goto('/login');
	await page.locator('input[name="email"]').fill(ADMIN_EMAIL);
	await page.locator('input[name="password"]').fill(ADMIN_PASSWORD);
	await page.getByRole('button', { name: /sign in/i }).click();
	await page.waitForURL(/\/admin/);
}

async function loginAsCoach(page: Page): Promise<void> {
	await page.goto('/login');
	await page.locator('input[name="email"]').fill(COACH_EMAIL);
	await page.locator('input[name="password"]').fill(COACH_PASSWORD);
	await page.getByRole('button', { name: /sign in/i }).click();
	await page.waitForURL(/\/team/);
}

async function runAxe(page: Page, route: string): Promise<void> {
	const analysis = await new AxeBuilder({ page })
		.withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'])
		.analyze();
	results.push({ route, violations: analysis.violations });
	console.log(
		`[a11y] ${route}: ${analysis.violations.length} violations`,
		analysis.violations.map((v) => `${v.impact} — ${v.id}: ${v.description}`)
	);
}

test.describe('a11y flows', () => {
	test.describe.configure({ mode: 'serial' });

	test('/login', async ({ page }) => {
		await page.goto('/login');
		await runAxe(page, '/login');
	});

	test('/register', async ({ page }) => {
		await page.goto('/register');
		await runAxe(page, '/register');
	});

	test('/register/teacher-coach', async ({ page }) => {
		await page.goto('/register/teacher-coach');
		// Page may show the form or a "registration closed" card — both are valid.
		await page.waitForLoadState('networkidle');
		await runAxe(page, '/register/teacher-coach');
	});

	test('/register/pending', async ({ page }) => {
		await page.goto('/register/pending');
		await page.waitForLoadState('networkidle');
		await runAxe(page, '/register/pending');
	});

	test('/team (as approved coach)', async ({ page }) => {
		test.skip(
			!COACH_EMAIL || !COACH_PASSWORD,
			'/team skipped: A11Y_COACH_EMAIL / A11Y_COACH_PASSWORD not set'
		);
		await loginAsCoach(page);
		await page.goto('/team');
		await page.waitForLoadState('networkidle');
		await runAxe(page, '/team');
	});

	test('/admin', async ({ page }) => {
		await loginAsAdmin(page);
		await page.goto('/admin');
		await page.waitForLoadState('networkidle');
		await runAxe(page, '/admin');
	});

	test('/admin/teams', async ({ page }) => {
		await loginAsAdmin(page);
		await page.goto('/admin/teams');
		await page.waitForLoadState('networkidle');
		await runAxe(page, '/admin/teams');
	});

	test('/admin/tournaments', async ({ page }) => {
		await loginAsAdmin(page);
		await page.goto('/admin/tournaments');
		await page.waitForLoadState('networkidle');
		await runAxe(page, '/admin/tournaments');
	});

	test.afterAll(() => {
		const outPath = new URL('../a11y-results.json', import.meta.url).pathname;
		writeFileSync(outPath, JSON.stringify(results, null, 2));
		console.log(`[a11y] Results written to ${outPath}`);

		// Print a quick summary table to stdout for the skill to capture.
		console.log('\n[a11y] Per-route violation summary:');
		console.log(
			'route'.padEnd(30) +
				'critical'.padEnd(10) +
				'serious'.padEnd(10) +
				'moderate'.padEnd(10) +
				'minor'
		);
		for (const r of results) {
			const counts = { critical: 0, serious: 0, moderate: 0, minor: 0 };
			for (const v of r.violations) {
				if (v.impact === 'critical') counts.critical++;
				else if (v.impact === 'serious') counts.serious++;
				else if (v.impact === 'moderate') counts.moderate++;
				else if (v.impact === 'minor') counts.minor++;
			}
			console.log(
				r.route.padEnd(30) +
					String(counts.critical).padEnd(10) +
					String(counts.serious).padEnd(10) +
					String(counts.moderate).padEnd(10) +
					String(counts.minor)
			);
		}
	});
});
