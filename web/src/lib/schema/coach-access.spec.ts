/**
 * Schema assertion tests for coach-gated collection access rules.
 *
 * Asserts that PocketBase migrations produced the expected rule strings for
 * every collection touched by the multi-coach migration (1800000009) and the
 * join-requests migration (1800000010).
 *
 * Run: `npm run test:schema` from repo root. The script starts the
 * isolated test PocketBase (docker-compose.test.yml) on port 28090
 * and sources .env.test for credentials.
 */

import { beforeAll, describe, expect, it } from 'vitest';
import { getCollection, type CollectionRules } from '../test-helpers/pb-admin';

function assertRules(col: CollectionRules | null): asserts col is CollectionRules {
	if (col === null) throw new Error('Collection not found');
}

// Shared shorthand rules
const COACH = 'coaches ~ @request.auth.id';
const TEAM_COACH = 'team.coaches ~ @request.auth.id';
const ROSTER_CHAIN = 'roster_entry.team.coaches ~ @request.auth.id';
const JOIN_LIST = 'user = @request.auth.id || team.coaches ~ @request.auth.id';

describe('teams — multi-relation coaches field', () => {
	let col: CollectionRules | null;
	beforeAll(async () => {
		col = await getCollection('teams');
	});

	it('coaches can list their own team', () => {
		assertRules(col);
		expect(col.listRule).toBe(COACH);
	});
	it('coaches can view their own team', () => {
		assertRules(col);
		expect(col.viewRule).toBe(COACH);
	});
	it('create is admin-only', () => {
		assertRules(col);
		expect(col.createRule).toBeNull();
	});
	it('update is admin-only', () => {
		assertRules(col);
		expect(col.updateRule).toBeNull();
	});
	it('delete is admin-only', () => {
		assertRules(col);
		expect(col.deleteRule).toBeNull();
	});
});

describe('eligibility_list_entries — all rules coach-gated', () => {
	let col: CollectionRules | null;
	beforeAll(async () => {
		col = await getCollection('eligibility_list_entries');
	});

	it('list', () => {
		assertRules(col);
		expect(col.listRule).toBe(TEAM_COACH);
	});
	it('view', () => {
		assertRules(col);
		expect(col.viewRule).toBe(TEAM_COACH);
	});
	it('create', () => {
		assertRules(col);
		expect(col.createRule).toBe(TEAM_COACH);
	});
	it('update', () => {
		assertRules(col);
		expect(col.updateRule).toBe(TEAM_COACH);
	});
	it('delete', () => {
		assertRules(col);
		expect(col.deleteRule).toBe(TEAM_COACH);
	});
});

describe('eligibility_change_requests — coaches create; admin approves', () => {
	let col: CollectionRules | null;
	beforeAll(async () => {
		col = await getCollection('eligibility_change_requests');
	});

	it('list', () => {
		assertRules(col);
		expect(col.listRule).toBe(TEAM_COACH);
	});
	it('view', () => {
		assertRules(col);
		expect(col.viewRule).toBe(TEAM_COACH);
	});
	it('create', () => {
		assertRules(col);
		expect(col.createRule).toBe(TEAM_COACH);
	});
	it('update is admin-only', () => {
		assertRules(col);
		expect(col.updateRule).toBeNull();
	});
	it('delete is admin-only', () => {
		assertRules(col);
		expect(col.deleteRule).toBeNull();
	});
});

describe('attorney_coaches — all rules coach-gated', () => {
	let col: CollectionRules | null;
	beforeAll(async () => {
		col = await getCollection('attorney_coaches');
	});

	it('list', () => {
		assertRules(col);
		expect(col.listRule).toBe(TEAM_COACH);
	});
	it('view', () => {
		assertRules(col);
		expect(col.viewRule).toBe(TEAM_COACH);
	});
	it('create', () => {
		assertRules(col);
		expect(col.createRule).toBe(TEAM_COACH);
	});
	it('update', () => {
		assertRules(col);
		expect(col.updateRule).toBe(TEAM_COACH);
	});
	it('delete', () => {
		assertRules(col);
		expect(col.deleteRule).toBe(TEAM_COACH);
	});
});

describe('withdrawal_requests — coaches create; admin resolves', () => {
	let col: CollectionRules | null;
	beforeAll(async () => {
		col = await getCollection('withdrawal_requests');
	});

	it('list', () => {
		assertRules(col);
		expect(col.listRule).toBe(TEAM_COACH);
	});
	it('view', () => {
		assertRules(col);
		expect(col.viewRule).toBe(TEAM_COACH);
	});
	it('create', () => {
		assertRules(col);
		expect(col.createRule).toBe(TEAM_COACH);
	});
	it('update is admin-only', () => {
		assertRules(col);
		expect(col.updateRule).toBeNull();
	});
	it('delete is admin-only', () => {
		assertRules(col);
		expect(col.deleteRule).toBeNull();
	});
});

describe('roster_submissions — public read; coach write', () => {
	let col: CollectionRules | null;
	beforeAll(async () => {
		col = await getCollection('roster_submissions');
	});

	it('list is public', () => {
		assertRules(col);
		expect(col.listRule).toBe('');
	});
	it('view is public', () => {
		assertRules(col);
		expect(col.viewRule).toBe('');
	});
	it('create', () => {
		assertRules(col);
		expect(col.createRule).toBe(TEAM_COACH);
	});
	it('update', () => {
		assertRules(col);
		expect(col.updateRule).toBe(TEAM_COACH);
	});
	it('delete is admin-only', () => {
		assertRules(col);
		expect(col.deleteRule).toBeNull();
	});
});

describe('roster_entries — public read; coach write', () => {
	let col: CollectionRules | null;
	beforeAll(async () => {
		col = await getCollection('roster_entries');
	});

	it('list is public', () => {
		assertRules(col);
		expect(col.listRule).toBe('');
	});
	it('view is public', () => {
		assertRules(col);
		expect(col.viewRule).toBe('');
	});
	it('create', () => {
		assertRules(col);
		expect(col.createRule).toBe(TEAM_COACH);
	});
	it('update', () => {
		assertRules(col);
		expect(col.updateRule).toBe(TEAM_COACH);
	});
	it('delete', () => {
		assertRules(col);
		expect(col.deleteRule).toBe(TEAM_COACH);
	});
});

describe('attorney_tasks — public read; coach write via roster chain', () => {
	let col: CollectionRules | null;
	beforeAll(async () => {
		col = await getCollection('attorney_tasks');
	});

	it('list is public', () => {
		assertRules(col);
		expect(col.listRule).toBe('');
	});
	it('view is public', () => {
		assertRules(col);
		expect(col.viewRule).toBe('');
	});
	it('create', () => {
		assertRules(col);
		expect(col.createRule).toBe(ROSTER_CHAIN);
	});
	it('update', () => {
		assertRules(col);
		expect(col.updateRule).toBe(ROSTER_CHAIN);
	});
	it('delete', () => {
		assertRules(col);
		expect(col.deleteRule).toBe(ROSTER_CHAIN);
	});
});

describe('join_requests — requester or existing coaches read; existing coaches approve', () => {
	let col: CollectionRules | null;
	beforeAll(async () => {
		col = await getCollection('join_requests');
	});

	it('list', () => {
		assertRules(col);
		expect(col.listRule).toBe(JOIN_LIST);
	});
	it('view', () => {
		assertRules(col);
		expect(col.viewRule).toBe(JOIN_LIST);
	});
	it('create is admin-only (hook creates)', () => {
		assertRules(col);
		expect(col.createRule).toBeNull();
	});
	it('update (approve/reject)', () => {
		assertRules(col);
		expect(col.updateRule).toBe(TEAM_COACH);
	});
	it('delete is admin-only', () => {
		assertRules(col);
		expect(col.deleteRule).toBeNull();
	});
});

describe('co_coaches — dropped in migration 1800000009', () => {
	it('collection does not exist', async () => {
		const col = await getCollection('co_coaches');
		expect(col).toBeNull();
	});
});
