/**
 * Hook integration tests for auth_guard.pb.js.
 *
 * Covers onRecordAuthRequest on "users":
 *   approved coach authenticates → 200, token returned
 *   pending coach authenticates → 403 ForbiddenError
 *   rejected coach authenticates → 403 ForbiddenError
 *
 * The auth guard fires on `status` regardless of `role`. Users are created
 * without `role: 'coach'` so the registration hook does not fire (it only
 * acts on role='coach' records), keeping this spec isolated from any
 * registration-status tournament.
 *
 * Run: `npm run test:hooks` from repo root.
 */

import { afterAll, describe, expect, it } from 'vitest';
import { pbCreate, pbDelete, PbError } from '../test-helpers/pb-admin';

const PB_URL = process.env.PB_URL!;

type Tracked = { collection: string; id: string };

const tracked: Tracked[] = [];

function track(collection: string, id: string) {
	tracked.push({ collection, id });
}

async function cleanup() {
	const failures: string[] = [];
	for (const { collection, id } of tracked) {
		try {
			await pbDelete(collection, id);
		} catch (err) {
			const detail =
				err instanceof PbError ? `${err.status} ${JSON.stringify(err.data)}` : String(err);
			failures.push(`${collection}/${id}: ${detail}`);
		}
	}
	tracked.length = 0;
	if (failures.length > 0) {
		throw new Error(
			`Cleanup left orphan records (${failures.length}). ` +
				`Hook tests must fully tear down state. Failures:\n  - ${failures.join('\n  - ')}`
		);
	}
}

async function pbAuth(
	email: string,
	password: string
): Promise<{ ok: boolean; status: number; data: unknown }> {
	const res = await fetch(`${PB_URL}/api/collections/users/auth-with-password`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ identity: email, password })
	});
	const data = await res.json();
	return { ok: res.ok, status: res.status, data };
}

afterAll(cleanup);

const RUN_ID = Date.now().toString(36);

describe('auth_guard', () => {
	it('allows login for approved user', async () => {
		const email = `hooks-auth-approved-${RUN_ID}@test.invalid`;
		const user = await pbCreate('users', {
			email,
			password: 'testpass123',
			passwordConfirm: 'testpass123',
			name: `hooks-auth-approved-${RUN_ID}`,
			status: 'approved'
		});
		track('users', (user as { id: string }).id);

		const result = await pbAuth(email, 'testpass123');
		expect(result.ok).toBe(true);
		expect(result.status).toBe(200);
		expect((result.data as { token?: string }).token).toBeTruthy();
	});

	it('blocks login for pending user with 403', async () => {
		const email = `hooks-auth-pending-${RUN_ID}@test.invalid`;
		const user = await pbCreate('users', {
			email,
			password: 'testpass123',
			passwordConfirm: 'testpass123',
			name: `hooks-auth-pending-${RUN_ID}`,
			status: 'pending'
		});
		track('users', (user as { id: string }).id);

		const result = await pbAuth(email, 'testpass123');
		expect(result.ok).toBe(false);
		expect(result.status).toBe(403);
	});

	it('blocks login for rejected user with 403', async () => {
		const email = `hooks-auth-rejected-${RUN_ID}@test.invalid`;
		const user = await pbCreate('users', {
			email,
			password: 'testpass123',
			passwordConfirm: 'testpass123',
			name: `hooks-auth-rejected-${RUN_ID}`,
			status: 'rejected'
		});
		track('users', (user as { id: string }).id);

		const result = await pbAuth(email, 'testpass123');
		expect(result.ok).toBe(false);
		expect(result.status).toBe(403);
	});
});
