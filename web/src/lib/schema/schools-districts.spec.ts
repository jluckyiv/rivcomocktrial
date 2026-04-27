/**
 * Schema assertion tests for schools and districts collections.
 *
 * Run: `npm run test:schema` from repo root.
 */

import { beforeAll, describe, expect, it } from 'vitest';
import { getCollection, type CollectionRules } from '../test-helpers/pb-admin';

function assertRules(col: CollectionRules | null): asserts col is CollectionRules {
	if (col === null) throw new Error('Collection not found');
}

describe('schools — public read; admin write', () => {
	let col: CollectionRules | null;
	beforeAll(async () => {
		col = await getCollection('schools');
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

describe('districts — public read; admin write', () => {
	let col: CollectionRules | null;
	beforeAll(async () => {
		col = await getCollection('districts');
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
