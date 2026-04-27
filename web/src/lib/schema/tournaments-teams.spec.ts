/**
 * Schema assertion tests for the tournaments_teams collection.
 *
 * tournaments_teams is the many-to-many join between tournaments and
 * teams. It tracks per-tournament eligibility status — separate from
 * the durable coach/team enrollment records.
 *
 * Run: `npm run test:schema` from repo root.
 */

import { beforeAll, describe, expect, it } from 'vitest';
import { getCollection, type CollectionRules } from '../test-helpers/pb-admin';

function assertRules(col: CollectionRules | null): asserts col is CollectionRules {
	if (col === null) throw new Error('Collection "tournaments_teams" not found');
}

describe('tournaments_teams — coach read; admin write', () => {
	let col: CollectionRules | null;
	beforeAll(async () => {
		col = await getCollection('tournaments_teams');
	});

	it('collection exists', () => {
		expect(col).not.toBeNull();
	});

	it('list is readable by coaches on the team', () => {
		assertRules(col);
		expect(col.listRule).toBe('team.coaches ~ @request.auth.id');
	});

	it('view is readable by coaches on the team', () => {
		assertRules(col);
		expect(col.viewRule).toBe('team.coaches ~ @request.auth.id');
	});

	it('create is admin-only (hooks write)', () => {
		assertRules(col);
		expect(col.createRule).toBeNull();
	});

	it('update is admin-only (hooks write)', () => {
		assertRules(col);
		expect(col.updateRule).toBeNull();
	});

	it('delete is admin-only', () => {
		assertRules(col);
		expect(col.deleteRule).toBeNull();
	});
});

describe('teams — teams.status field removed', () => {
	it('teams collection no longer has a status field', async () => {
		const token_res = await fetch(
			`${process.env.PB_URL}/api/collections/_superusers/auth-with-password`,
			{
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					identity: process.env.PB_ADMIN_EMAIL,
					password: process.env.PB_ADMIN_PASSWORD
				})
			}
		);
		const { token } = (await token_res.json()) as { token: string };

		const res = await fetch(`${process.env.PB_URL}/api/collections/teams`, {
			headers: { Authorization: token }
		});
		const col = (await res.json()) as { fields: Array<{ name: string }> };
		const fieldNames = col.fields.map((f) => f.name);
		expect(fieldNames).not.toContain('status');
	});
});
