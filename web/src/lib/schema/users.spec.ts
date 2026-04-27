/**
 * Schema assertion tests for the users collection.
 *
 * Run: `npm run test:schema` from repo root.
 */

import { beforeAll, describe, expect, it } from 'vitest';
import { getCollection, type CollectionRules } from '../test-helpers/pb-admin';

function assertRules(col: CollectionRules | null): asserts col is CollectionRules {
	if (col === null) throw new Error('Collection not found');
}

describe('users — public register; admin manages', () => {
	let col: CollectionRules | null;
	beforeAll(async () => {
		col = await getCollection('users');
	});

	it('list is admin-only', () => {
		assertRules(col);
		expect(col.listRule).toBeNull();
	});
	it('view is admin-only', () => {
		assertRules(col);
		expect(col.viewRule).toBeNull();
	});
	it('create is public (self-registration)', () => {
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
