/**
 * Schema assertion tests for tournament-related collections:
 * tournaments, rounds, trials, students, case_characters, courtrooms.
 *
 * Run: `npm run test:schema` from repo root.
 */

import { beforeAll, describe, expect, it } from 'vitest';
import { getCollection, type CollectionRules } from '../test-helpers/pb-admin';

function assertRules(col: CollectionRules | null): asserts col is CollectionRules {
	if (col === null) throw new Error('Collection not found');
}

describe('tournaments — public read; admin write', () => {
	let col: CollectionRules | null;
	beforeAll(async () => {
		col = await getCollection('tournaments');
	});

	it('list is public', () => {
		assertRules(col);
		expect(col.listRule).toBe('');
	});
	it('view is public', () => {
		assertRules(col);
		expect(col.viewRule).toBe('');
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

describe('rounds — public read; admin write', () => {
	let col: CollectionRules | null;
	beforeAll(async () => {
		col = await getCollection('rounds');
	});

	it('list is public', () => {
		assertRules(col);
		expect(col.listRule).toBe('');
	});
	it('view is public', () => {
		assertRules(col);
		expect(col.viewRule).toBe('');
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

describe('trials — public read; admin write', () => {
	let col: CollectionRules | null;
	beforeAll(async () => {
		col = await getCollection('trials');
	});

	it('list is public', () => {
		assertRules(col);
		expect(col.listRule).toBe('');
	});
	it('view is public', () => {
		assertRules(col);
		expect(col.viewRule).toBe('');
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

describe('students — public read; admin write', () => {
	let col: CollectionRules | null;
	beforeAll(async () => {
		col = await getCollection('students');
	});

	it('list is public', () => {
		assertRules(col);
		expect(col.listRule).toBe('');
	});
	it('view is public', () => {
		assertRules(col);
		expect(col.viewRule).toBe('');
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

describe('case_characters — public read; admin write', () => {
	let col: CollectionRules | null;
	beforeAll(async () => {
		col = await getCollection('case_characters');
	});

	it('list is public', () => {
		assertRules(col);
		expect(col.listRule).toBe('');
	});
	it('view is public', () => {
		assertRules(col);
		expect(col.viewRule).toBe('');
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

describe('courtrooms — admin-only', () => {
	let col: CollectionRules | null;
	beforeAll(async () => {
		col = await getCollection('courtrooms');
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
