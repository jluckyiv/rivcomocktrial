import { describe, expect, test } from 'vitest';
import { empty, fromRecords, hasPlayed, sideHistory } from './matchHistory';

type Team = { id: string; name: string };

const team01: Team = { id: '1', name: 'Palm Desert' };
const team02: Team = { id: '2', name: 'Santiago' };
const team03: Team = { id: '3', name: 'Vista del Lago' };
const team04: Team = { id: '4', name: 'Murrieta Valley' };
const team06: Team = { id: '6', name: 'La Quinta' };
const team09: Team = { id: '9', name: 'Notre Dame' };
const team15: Team = { id: '15', name: 'Indio' };
const team19: Team = { id: '19', name: 'John W. North' };
const team23: Team = { id: '23', name: 'Paloma Valley' };

describe('MatchHistory', () => {
	describe('empty', () => {
		test('empty history has no matches', () => {
			expect(hasPlayed(empty<Team>(), team01, team02)).toBe(false);
		});
		test('empty history has zero side counts', () => {
			expect(sideHistory(empty<Team>(), team01)).toEqual({ prosecution: 0, defense: 0 });
		});
	});

	describe('hasPlayed', () => {
		test('detects previous matchup (P vs D)', () => {
			const history = fromRecords([{ prosecution: team06, defense: team15 }]);
			expect(hasPlayed(history, team06, team15)).toBe(true);
		});
		test('detects previous matchup (reversed order)', () => {
			const history = fromRecords([{ prosecution: team06, defense: team15 }]);
			expect(hasPlayed(history, team15, team06)).toBe(true);
		});
		test('returns false for teams that have not played', () => {
			const history = fromRecords([{ prosecution: team06, defense: team15 }]);
			expect(hasPlayed(history, team01, team06)).toBe(false);
		});
		test('works with multiple records', () => {
			const history = fromRecords([
				{ prosecution: team01, defense: team02 },
				{ prosecution: team03, defense: team04 }
			]);
			expect(hasPlayed(history, team01, team02)).toBe(true);
			expect(hasPlayed(history, team03, team04)).toBe(true);
			expect(hasPlayed(history, team01, team03)).toBe(false);
		});
	});

	describe('sideHistory', () => {
		test('counts prosecution and defense appearances', () => {
			const history = fromRecords([
				{ prosecution: team19, defense: team09 },
				{ prosecution: team09, defense: team23 }
			]);
			expect(sideHistory(history, team09)).toEqual({ prosecution: 1, defense: 1 });
		});
		test('team with no appearances has zero counts', () => {
			const history = fromRecords([{ prosecution: team01, defense: team02 }]);
			expect(sideHistory(history, team03)).toEqual({ prosecution: 0, defense: 0 });
		});
		test('team as prosecution only', () => {
			const history = fromRecords([{ prosecution: team06, defense: team15 }]);
			expect(sideHistory(history, team06)).toEqual({ prosecution: 1, defense: 0 });
		});
		test('team as defense only', () => {
			const history = fromRecords([{ prosecution: team06, defense: team15 }]);
			expect(sideHistory(history, team15)).toEqual({ prosecution: 0, defense: 1 });
		});
	});
});
