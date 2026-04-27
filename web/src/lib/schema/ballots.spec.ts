/**
 * Schema assertion tests for ballot-related collections:
 * ballot_submissions, ballot_scores, presider_ballots,
 * ballot_corrections, judges, scorer_tokens.
 *
 * Run: `npm run test:schema` from repo root.
 */

import { beforeAll, describe, expect, it } from 'vitest';
import { getCollection, type CollectionRules } from '../test-helpers/pb-admin';

function assertRules(col: CollectionRules | null): asserts col is CollectionRules {
	if (col === null) throw new Error('Collection not found');
}

// scorer_tokens uses a token-in-query-param gate for its read rules
const TOKEN_QUERY = 'token = @request.query.token';

describe('ballot_submissions — public create; admin manages', () => {
	let col: CollectionRules | null;
	beforeAll(async () => {
		col = await getCollection('ballot_submissions');
	});

	it('list is admin-only', () => {
		assertRules(col);
		expect(col.listRule).toBeNull();
	});
	it('view is admin-only', () => {
		assertRules(col);
		expect(col.viewRule).toBeNull();
	});
	it('create is public (scorer submits)', () => {
		assertRules(col);
		expect(col.createRule).toBe('');
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

describe('ballot_scores — public create; admin manages', () => {
	let col: CollectionRules | null;
	beforeAll(async () => {
		col = await getCollection('ballot_scores');
	});

	it('list is admin-only', () => {
		assertRules(col);
		expect(col.listRule).toBeNull();
	});
	it('view is admin-only', () => {
		assertRules(col);
		expect(col.viewRule).toBeNull();
	});
	it('create is public (scorer submits)', () => {
		assertRules(col);
		expect(col.createRule).toBe('');
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

describe('presider_ballots — public create; admin manages', () => {
	let col: CollectionRules | null;
	beforeAll(async () => {
		col = await getCollection('presider_ballots');
	});

	it('list is admin-only', () => {
		assertRules(col);
		expect(col.listRule).toBeNull();
	});
	it('view is admin-only', () => {
		assertRules(col);
		expect(col.viewRule).toBeNull();
	});
	it('create is public (presider submits)', () => {
		assertRules(col);
		expect(col.createRule).toBe('');
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

describe('ballot_corrections — admin-only', () => {
	let col: CollectionRules | null;
	beforeAll(async () => {
		col = await getCollection('ballot_corrections');
	});

	it('list is admin-only', () => {
		assertRules(col);
		expect(col.listRule).toBeNull();
	});
	it('view is admin-only', () => {
		assertRules(col);
		expect(col.viewRule).toBeNull();
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

describe('judges — admin-only', () => {
	let col: CollectionRules | null;
	beforeAll(async () => {
		col = await getCollection('judges');
	});

	it('list is admin-only', () => {
		assertRules(col);
		expect(col.listRule).toBeNull();
	});
	it('view is admin-only', () => {
		assertRules(col);
		expect(col.viewRule).toBeNull();
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

describe('scorer_tokens — token-gated read; admin write', () => {
	let col: CollectionRules | null;
	beforeAll(async () => {
		col = await getCollection('scorer_tokens');
	});

	it('list requires token query param', () => {
		assertRules(col);
		expect(col.listRule).toBe(TOKEN_QUERY);
	});
	it('view requires token query param', () => {
		assertRules(col);
		expect(col.viewRule).toBe(TOKEN_QUERY);
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
