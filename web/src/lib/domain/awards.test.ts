import { describe, expect, test } from 'vitest';
import {
	type AwardCategory,
	type Student,
	type Witness,
	nominationCategory,
	scoreByRankPoints
} from './awards';

const alice: Student = { firstName: 'Alice', lastName: 'Smith' };
const bob: Student = { firstName: 'Bob', lastName: 'Jones' };

const w1: Witness = { name: 'Jordan Riley', role: 'Lead Investigator' };
const w2: Witness = { name: 'Casey Morgan', role: 'Expert Analyst' };

describe('Awards', () => {
	describe('nominationCategory', () => {
		test('BestAttorney Prosecution → Advocate', () => {
			expect(nominationCategory({ kind: 'BestAttorney', side: 'Prosecution' })).toBe('__BROKEN__');
		});

		test('BestAttorney Defense → Advocate', () => {
			expect(nominationCategory({ kind: 'BestAttorney', side: 'Defense' })).toBe('Advocate');
		});

		test('BestWitness → NonAdvocate', () => {
			expect(nominationCategory({ kind: 'BestWitness', witness: w1 })).toBe('NonAdvocate');
		});

		test('BestClerk → NonAdvocate', () => {
			expect(nominationCategory({ kind: 'BestClerk' })).toBe('NonAdvocate');
		});

		test('BestBailiff → NonAdvocate', () => {
			expect(nominationCategory({ kind: 'BestBailiff' })).toBe('NonAdvocate');
		});
	});

	describe('scoreByRankPoints', () => {
		test('empty input → []', () => {
			expect(scoreByRankPoints([])).toEqual([]);
		});

		test('single student single rank', () => {
			const result = scoreByRankPoints([[alice, { kind: 'BestClerk' }, [1]]]);
			expect(result.map((s) => s.totalRankPoints)).toEqual([1]);
		});

		test('multiple students sorted descending', () => {
			const result = scoreByRankPoints([
				[bob, { kind: 'BestClerk' }, [2]],
				[alice, { kind: 'BestBailiff' }, [1]]
			]);
			expect(result.map((s) => s.totalRankPoints)).toEqual([2, 1]);
		});

		test('multiple rounds accumulate', () => {
			const result = scoreByRankPoints([
				[alice, { kind: 'BestClerk' }, [1, 2]],
				[bob, { kind: 'BestBailiff' }, [2, 1]]
			]);
			expect(result.map((s) => s.totalRankPoints)).toEqual([3, 3]);
		});

		test('equal totals preserved in input order', () => {
			const result = scoreByRankPoints([
				[alice, { kind: 'BestClerk' }, [1]],
				[bob, { kind: 'BestBailiff' }, [1]]
			]);
			expect(result.map((s) => s.student)).toEqual([alice, bob]);
		});

		test('empty rank list → 0 points', () => {
			const result = scoreByRankPoints([[alice, { kind: 'BestClerk' }, []]]);
			expect(result.map((s) => s.totalRankPoints)).toEqual([0]);
		});

		test('StudentScore includes category', () => {
			const cat: AwardCategory = { kind: 'BestClerk' };
			const result = scoreByRankPoints([[alice, cat, [1]]]);
			expect(result.map((s) => s.category)).toEqual([cat]);
		});
	});

	describe('ranks not combined across roles', () => {
		function expectSeparateScores(
			entry1: [Student, AwardCategory, number[]],
			entry2: [Student, AwardCategory, number[]]
		) {
			expect(scoreByRankPoints([entry1, entry2])).toHaveLength(2);
		}

		test('pretrial + trial attorney (different sides)', () => {
			expectSeparateScores(
				[alice, { kind: 'BestAttorney', side: 'Prosecution' }, [1]],
				[alice, { kind: 'BestAttorney', side: 'Defense' }, [2]]
			);
		});

		test('pretrial + witness (same side)', () => {
			expectSeparateScores(
				[alice, { kind: 'BestAttorney', side: 'Prosecution' }, [1]],
				[alice, { kind: 'BestWitness', witness: w1 }, [2]]
			);
		});

		test('pretrial + witness (different sides)', () => {
			expectSeparateScores(
				[alice, { kind: 'BestAttorney', side: 'Prosecution' }, [1]],
				[alice, { kind: 'BestWitness', witness: w2 }, [2]]
			);
		});

		test('pretrial + clerk', () => {
			expectSeparateScores(
				[alice, { kind: 'BestAttorney', side: 'Prosecution' }, [1]],
				[alice, { kind: 'BestClerk' }, [2]]
			);
		});

		test('pretrial + bailiff', () => {
			expectSeparateScores(
				[alice, { kind: 'BestAttorney', side: 'Prosecution' }, [1]],
				[alice, { kind: 'BestBailiff' }, [2]]
			);
		});

		test('trial attorney on both sides', () => {
			expectSeparateScores(
				[alice, { kind: 'BestAttorney', side: 'Prosecution' }, [1]],
				[alice, { kind: 'BestAttorney', side: 'Defense' }, [2]]
			);
		});

		test('trial attorney + witness', () => {
			expectSeparateScores(
				[alice, { kind: 'BestAttorney', side: 'Defense' }, [1]],
				[alice, { kind: 'BestWitness', witness: w1 }, [2]]
			);
		});

		test('trial attorney + clerk', () => {
			expectSeparateScores(
				[alice, { kind: 'BestAttorney', side: 'Defense' }, [1]],
				[alice, { kind: 'BestClerk' }, [2]]
			);
		});

		test('trial attorney + bailiff', () => {
			expectSeparateScores(
				[alice, { kind: 'BestAttorney', side: 'Defense' }, [1]],
				[alice, { kind: 'BestBailiff' }, [2]]
			);
		});

		test('witness on both sides', () => {
			expectSeparateScores(
				[alice, { kind: 'BestWitness', witness: w1 }, [1]],
				[alice, { kind: 'BestWitness', witness: w2 }, [2]]
			);
		});

		test('witness + clerk', () => {
			expectSeparateScores(
				[alice, { kind: 'BestWitness', witness: w1 }, [1]],
				[alice, { kind: 'BestClerk' }, [2]]
			);
		});

		test('witness + bailiff', () => {
			expectSeparateScores(
				[alice, { kind: 'BestWitness', witness: w1 }, [1]],
				[alice, { kind: 'BestBailiff' }, [2]]
			);
		});

		test('clerk + bailiff', () => {
			expectSeparateScores(
				[alice, { kind: 'BestClerk' }, [1]],
				[alice, { kind: 'BestBailiff' }, [2]]
			);
		});
	});
});
