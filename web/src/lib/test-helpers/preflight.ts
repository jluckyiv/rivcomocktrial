import { beforeAll } from 'vitest';

const PB_URL = process.env.PB_URL;

beforeAll(async () => {
	if (!PB_URL) return;
	try {
		await fetch(`${PB_URL}/api/health`, { signal: AbortSignal.timeout(2000) });
	} catch {
		throw new Error(
			`PocketBase is not reachable on ${PB_URL}.\n` +
				`Start the test container, then re-run:\n` +
				`  npm run pb:test:up    (from repo root)\n` +
				`  npx vitest run --project=server`
		);
	}
}, 5000);
