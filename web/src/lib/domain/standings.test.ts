import { describe, expect, test } from 'vitest'
import {
	ByHeadToHead,
	ByCumulativePercentage,
	ByPointDifferential,
	ByWins,
	cumulativePercentage,
	losses,
	pointsAgainst,
	pointsFor,
	rank,
	teamRecord,
	wins,
	type TeamRecord,
} from './standings'

function record(w: number, l: number, pf: number, pa: number): TeamRecord {
	return teamRecord({ wins: w, losses: l, pointsFor: pf, pointsAgainst: pa })
}

describe('Standings', () => {
	describe('teamRecord', () => {
		test('wins accessor', () => {
			expect(wins(record(3, 1, 300, 200))).toBe(3)
		})
		test('losses accessor', () => {
			expect(losses(record(3, 1, 300, 200))).toBe(1)
		})
		test('pointsFor accessor', () => {
			expect(pointsFor(record(3, 1, 300, 200))).toBe(300)
		})
		test('pointsAgainst accessor', () => {
			expect(pointsAgainst(record(3, 1, 300, 200))).toBe(200)
		})
	})

	describe('cumulativePercentage', () => {
		test('pointsFor / (pointsFor + pointsAgainst)', () => {
			expect(cumulativePercentage(record(2, 1, 300, 200))).toBeCloseTo(0.6, 3)
		})
		test('returns 0 when no points', () => {
			expect(cumulativePercentage(record(0, 0, 0, 0))).toBeCloseTo(0.0, 3)
		})
		test('100% when opponent scored 0', () => {
			expect(cumulativePercentage(record(1, 0, 100, 0))).toBeCloseTo(1.0, 3)
		})
	})

	describe('rank', () => {
		test('by ByWins — more wins ranked higher', () => {
			const entries: [string, TeamRecord][] = [
				['B', record(1, 2, 200, 300)],
				['A', record(3, 0, 300, 200)],
			]
			expect(rank([ByWins], entries).map(([t]) => t)).toEqual(['A', 'B'])
		})
		test('by ByCumulativePercentage — higher % first', () => {
			const entries: [string, TeamRecord][] = [
				['B', record(1, 1, 200, 300)],
				['A', record(1, 1, 400, 200)],
			]
			expect(rank([ByCumulativePercentage], entries).map(([t]) => t)).toEqual(['A', 'B'])
		})
		test('by ByPointDifferential — higher diff first', () => {
			const entries: [string, TeamRecord][] = [
				['B', record(1, 1, 200, 300)],
				['A', record(1, 1, 400, 200)],
			]
			expect(rank([ByPointDifferential], entries).map(([t]) => t)).toEqual(['A', 'B'])
		})
		test('strategy [ByWins, ByCumulativePercentage] — wins primary, % breaks ties', () => {
			const entries: [string, TeamRecord][] = [
				['C', record(2, 1, 200, 300)],
				['A', record(2, 1, 400, 200)],
				['B', record(3, 0, 300, 200)],
			]
			expect(rank([ByWins, ByCumulativePercentage], entries).map(([t]) => t)).toEqual([
				'B',
				'A',
				'C',
			])
		})
		test('equal records maintain relative order', () => {
			const entries: [string, TeamRecord][] = [
				['A', record(2, 1, 300, 200)],
				['B', record(2, 1, 300, 200)],
			]
			expect(rank([ByWins, ByCumulativePercentage], entries).map(([t]) => t)).toEqual(['A', 'B'])
		})
	})

	describe('ByHeadToHead', () => {
		function headToHeadLookup(winsOverList: [string, string][]) {
			return (a: string, b: string): number => {
				if (winsOverList.some(([w, l]) => w === a && l === b)) return -1
				if (winsOverList.some(([w, l]) => w === b && l === a)) return 1
				return 0
			}
		}

		test('breaks tie between equal teams', () => {
			const h2h = ByHeadToHead(headToHeadLookup([['A', 'B']]))
			const entries: [string, TeamRecord][] = [
				['B', record(2, 1, 300, 200)],
				['A', record(2, 1, 300, 200)],
			]
			expect(rank([ByWins, h2h], entries).map(([t]) => t)).toEqual(['A', 'B'])
		})
		test('falls through to next tiebreaker after EQ', () => {
			const h2h = ByHeadToHead((_a: string, _b: string) => 0)
			const entries: [string, TeamRecord][] = [
				['B', record(2, 1, 200, 300)],
				['A', record(2, 1, 400, 200)],
			]
			expect(rank([ByWins, h2h, ByCumulativePercentage], entries).map(([t]) => t)).toEqual([
				'A',
				'B',
			])
		})
		test('sole strategy orders correctly', () => {
			const h2h = ByHeadToHead(headToHeadLookup([['X', 'Y']]))
			const entries: [string, TeamRecord][] = [
				['Y', record(0, 0, 0, 0)],
				['X', record(0, 0, 0, 0)],
			]
			expect(rank([h2h], entries).map(([t]) => t)).toEqual(['X', 'Y'])
		})
		test('unknown matchup returns EQ preserves order', () => {
			const h2h = ByHeadToHead(headToHeadLookup([]))
			const entries: [string, TeamRecord][] = [
				['A', record(2, 1, 300, 200)],
				['B', record(2, 1, 300, 200)],
			]
			expect(rank([h2h], entries).map(([t]) => t)).toEqual(['A', 'B'])
		})
	})
})
