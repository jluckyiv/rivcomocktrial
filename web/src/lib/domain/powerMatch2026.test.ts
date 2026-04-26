import { describe, expect, test } from 'vitest';
import { hasPlayed, sideHistory, toRecords, type MatchHistory } from './matchHistory';
import { powerMatch } from './powerMatch';
import * as F from './powerMatchFixtures';

const rt = F.rankedTeam;

const rankedAfterR3 = [
	rt(F.team01, 3, 0, 1),
	rt(F.team09, 3, 0, 2),
	rt(F.team12, 3, 0, 3),
	rt(F.team13, 3, 0, 4),
	rt(F.team02, 2, 1, 1),
	rt(F.team05, 2, 1, 2),
	rt(F.team10, 2, 1, 3),
	rt(F.team15, 2, 1, 4),
	rt(F.team16, 2, 1, 5),
	rt(F.team20, 2, 1, 6),
	rt(F.team22, 2, 1, 7),
	rt(F.team25, 2, 1, 8),
	rt(F.team27, 2, 1, 9),
	rt(F.team04, 1, 2, 1),
	rt(F.team06, 1, 2, 2),
	rt(F.team08, 1, 2, 3),
	rt(F.team11, 1, 2, 4),
	rt(F.team19, 1, 2, 5),
	rt(F.team21, 1, 2, 6),
	rt(F.team23, 1, 2, 7),
	rt(F.team26, 1, 2, 8),
	rt(F.team28, 1, 2, 9),
	rt(F.team03, 0, 3, 1),
	rt(F.team14, 0, 3, 2),
	rt(F.team17, 0, 3, 3),
	rt(F.team24, 0, 3, 4)
];

// WIN RESULTS: maps (prosecution, defense) team number pairs to winning team number
const winResults = new Map<string, number>([
	// Round 1
	['6,15', 15],
	['24,1', 1],
	['19,9', 9],
	['8,11', 8],
	['5,27', 27],
	['26,13', 13],
	['10,2', 2],
	['3,16', 16],
	['4,14', 4],
	['28,25', 25],
	['22,17', 22],
	['21,12', 12],
	['23,20', 20],
	// Round 2
	['9,23', 9],
	['2,19', 19],
	['27,21', 27],
	['16,22', 22],
	['13,4', 13],
	['12,6', 12],
	['25,3', 25],
	['15,5', 5],
	['11,24', 11],
	['20,26', 20],
	['14,28', 28],
	['17,10', 10],
	['1,8', 1],
	// Round 3
	['25,1', 1],
	['28,5', 5],
	['23,17', 23],
	['20,12', 12],
	['6,3', 6],
	['4,2', 2],
	['26,14', 26],
	['10,8', 10],
	['19,16', 16],
	['22,9', 9],
	['21,24', 21],
	['15,11', 15],
	['27,13', 13],
	// Round 4
	['2,15', 2],
	['16,25', 16],
	['13,21', 13],
	['24,26', 26],
	['12,22', 22],
	['11,28', 11],
	['5,10', 10],
	['1,27', 27],
	['3,23', 23],
	['8,4', 4],
	['14,6', 14],
	['17,19', 19],
	['9,20', 9]
]);

function countWins(history: MatchHistory<F.Team>): Map<number, number> {
	const counts = new Map<number, number>();
	for (const r of toRecords(history)) {
		const key = `${r.prosecution.number},${r.defense.number}`;
		const winner = winResults.get(key);
		if (winner !== undefined) {
			counts.set(winner, (counts.get(winner) ?? 0) + 1);
		}
	}
	return counts;
}

function getWins(winsMap: Map<number, number>, team: F.Team): number {
	return winsMap.get(team.number) ?? 0;
}

function normalizeMatchup(a: number, b: number): [number, number] {
	return a < b ? [a, b] : [b, a];
}

function findDuplicates(matchups: [number, number][]): [number, number][] {
	const seen: [number, number][] = [];
	const dupes: [number, number][] = [];
	for (const m of matchups) {
		if (seen.some(([a, b]) => a === m[0] && b === m[1])) {
			dupes.push(m);
		} else {
			seen.push(m);
		}
	}
	return dupes;
}

function rematches(
	priorHistory: MatchHistory<F.Team>,
	roundHistory: MatchHistory<F.Team>
): string[] {
	return toRecords(roundHistory)
		.filter((r) => hasPlayed(priorHistory, r.prosecution, r.defense))
		.map((r) => `${r.prosecution.number} vs ${r.defense.number}`);
}

describe('PowerMatch 2026', () => {
	describe('side balance', () => {
		test('every team plays prosecution exactly 2 times', () => {
			const allHistory = F.historyThrough(4);
			const violations = F.allTeams.filter(
				(team) => sideHistory(allHistory, team).prosecution !== 2
			);
			expect(violations.map((t) => t.number)).toEqual([]);
		});
		test('every team plays defense exactly 2 times', () => {
			const allHistory = F.historyThrough(4);
			const violations = F.allTeams.filter((team) => sideHistory(allHistory, team).defense !== 2);
			expect(violations.map((t) => t.number)).toEqual([]);
		});
	});

	describe('no rematches', () => {
		test('R2 has no rematches from R1', () => {
			expect(rematches(F.round1History, F.round2History)).toEqual([]);
		});
		test('R3 has no rematches from R1-R2', () => {
			expect(rematches(F.historyThrough(2), F.round3History)).toEqual([]);
		});
		test('R4 has no rematches from R1-R3', () => {
			expect(rematches(F.historyThrough(3), F.round4History)).toEqual([]);
		});
		test('no team faces the same opponent twice across all 4 rounds', () => {
			const allRecords = toRecords(F.historyThrough(4));
			const matchups = allRecords.map((r) =>
				normalizeMatchup(r.prosecution.number, r.defense.number)
			);
			expect(findDuplicates(matchups)).toEqual([]);
		});
	});

	describe('side switching', () => {
		test('R1 prosecution teams play R2 defense', () => {
			const r1ProsecutionNums = toRecords(F.round1History).map((r) => r.prosecution.number);
			const violations = toRecords(F.round2History).filter((r) =>
				r1ProsecutionNums.includes(r.prosecution.number)
			);
			expect(violations.map((r) => r.prosecution.number)).toEqual([]);
		});
		test('R1 defense teams play R2 prosecution', () => {
			const r1DefenseNums = toRecords(F.round1History).map((r) => r.defense.number);
			const violations = toRecords(F.round2History).filter((r) =>
				r1DefenseNums.includes(r.defense.number)
			);
			expect(violations.map((r) => r.defense.number)).toEqual([]);
		});
		test('R3 prosecution teams play R4 defense', () => {
			const r3ProsecutionNums = toRecords(F.round3History).map((r) => r.prosecution.number);
			const violations = toRecords(F.round4History).filter((r) =>
				r3ProsecutionNums.includes(r.prosecution.number)
			);
			expect(violations.map((r) => r.prosecution.number)).toEqual([]);
		});
		test('R3 defense teams play R4 prosecution', () => {
			const r3DefenseNums = toRecords(F.round3History).map((r) => r.defense.number);
			const violations = toRecords(F.round4History).filter((r) =>
				r3DefenseNums.includes(r.defense.number)
			);
			expect(violations.map((r) => r.defense.number)).toEqual([]);
		});
	});

	describe('bracket placement', () => {
		test('R3 pairings are all within-bracket (0 cross-bracket)', () => {
			const winsAfterR2 = countWins(F.historyThrough(2));
			const crossBracket = toRecords(F.round3History).filter(
				(r) => getWins(winsAfterR2, r.prosecution) !== getWins(winsAfterR2, r.defense)
			);
			expect(crossBracket.length).toBe(0);
		});
		test('R2 has 7 cross-bracket pairings', () => {
			const winsAfterR1 = countWins(F.round1History);
			const crossBracket = toRecords(F.round2History).filter(
				(r) => getWins(winsAfterR1, r.prosecution) !== getWins(winsAfterR1, r.defense)
			);
			expect(crossBracket.length).toBe(7);
		});
		test('R4 has 8 cross-bracket pairings', () => {
			const winsAfterR3 = countWins(F.historyThrough(3));
			const crossBracket = toRecords(F.round4History).filter(
				(r) => getWins(winsAfterR3, r.prosecution) !== getWins(winsAfterR3, r.defense)
			);
			expect(crossBracket.length).toBe(8);
		});
	});

	describe('trial counts', () => {
		test('13 trials per round', () => {
			expect([
				toRecords(F.round1History).length,
				toRecords(F.round2History).length,
				toRecords(F.round3History).length,
				toRecords(F.round4History).length
			]).toEqual([13, 13, 13, 13]);
		});
		test('every team plays exactly 4 trials total', () => {
			const allRecords = toRecords(F.historyThrough(4));
			const violations = F.allTeams.filter((team) => {
				const count = allRecords.filter((r) => r.prosecution === team || r.defense === team).length;
				return count !== 4;
			});
			expect(violations.map((t) => t.number)).toEqual([]);
		});
		test('26 unique teams across all trials', () => {
			const allRecords = toRecords(F.historyThrough(4));
			const allNums = allRecords.flatMap((r) => [r.prosecution.number, r.defense.number]);
			const unique = [...new Set(allNums)];
			expect(unique.length).toBe(26);
		});
	});

	describe('win/loss records', () => {
		test('standings after R1: 13 winners, 13 losers', () => {
			const wins = countWins(F.round1History);
			const oneWin = F.allTeams.filter((t) => getWins(wins, t) === 1).length;
			const zeroWins = F.allTeams.filter((t) => getWins(wins, t) === 0).length;
			expect([oneWin, zeroWins]).toEqual([13, 13]);
		});
		test('R1 winners are teams 1,2,4,8,9,12,13,15,16,20,22,25,27', () => {
			const wins = countWins(F.round1History);
			const winners = F.allTeams
				.filter((t) => getWins(wins, t) === 1)
				.map((t) => t.number)
				.sort((a, b) => a - b);
			expect(winners).toEqual([1, 2, 4, 8, 9, 12, 13, 15, 16, 20, 22, 25, 27]);
		});
		test('standings after R4: 2 at 4-0, 7 at 3-1, 9 at 2-2, 5 at 1-3, 3 at 0-4', () => {
			const wins = countWins(F.historyThrough(4));
			const byRecord = [4, 3, 2, 1, 0].map(
				(w) => F.allTeams.filter((t) => getWins(wins, t) === w).length
			);
			expect(byRecord).toEqual([2, 7, 9, 5, 3]);
		});
		test('4-0 teams are Notre Dame (9) and Poly (13)', () => {
			const wins = countWins(F.historyThrough(4));
			const fourOh = F.allTeams
				.filter((t) => getWins(wins, t) === 4)
				.map((t) => t.number)
				.sort((a, b) => a - b);
			expect(fourOh).toEqual([9, 13]);
		});
	});

	describe('R4: Chaparral moved to avoid Ramona rematch', () => {
		test('Ramona (16) and Chaparral (22) played in R2', () => {
			expect(hasPlayed(F.round2History, F.team16, F.team22)).toBe(true);
		});
		test('both are 2-1 going into R4', () => {
			const wins = countWins(F.historyThrough(3));
			expect([getWins(wins, F.team16), getWins(wins, F.team22)]).toEqual([2, 2]);
		});
		test('Ramona needs P in R4 (played D in R3)', () => {
			expect(sideHistory(F.round3History, F.team16)).toEqual({ prosecution: 0, defense: 1 });
		});
		test('Chaparral needs D in R4 (played P in R3)', () => {
			expect(sideHistory(F.round3History, F.team22)).toEqual({ prosecution: 1, defense: 0 });
		});
		test('without the R2 matchup, they would be paired', () => {
			const ranked = [rt(F.team16, 2, 1, 1), rt(F.team22, 2, 1, 2)];
			const priorHistory = F.fromRecords([
				{ prosecution: F.team19, defense: F.team16 },
				{ prosecution: F.team22, defense: F.team09 }
			]);
			const result = powerMatch('HighHigh', ranked, priorHistory, F.empty());
			const paired = result.pairings.some(
				(p) => p.prosecutionTeam === F.team16 && p.defenseTeam === F.team22
			);
			expect(paired).toBe(true);
		});
		test('the R2 matchup prevents that pairing', () => {
			const ranked = [rt(F.team16, 2, 1, 1), rt(F.team22, 2, 1, 2)];
			const priorHistory = F.fromRecords([
				{ prosecution: F.team19, defense: F.team16 },
				{ prosecution: F.team22, defense: F.team09 },
				{ prosecution: F.team16, defense: F.team22 }
			]);
			const result = powerMatch('HighHigh', ranked, priorHistory, F.empty());
			expect(result.pairings.length).toBe(0);
		});
		test('powerMatch does not pair Ramona with Chaparral in R4 (HighHigh)', () => {
			const priorHistory = F.historyThrough(3);
			const result = powerMatch('HighHigh', rankedAfterR3, priorHistory, F.empty());
			const paired = result.pairings.some(
				(p) =>
					(p.prosecutionTeam === F.team16 && p.defenseTeam === F.team22) ||
					(p.prosecutionTeam === F.team22 && p.defenseTeam === F.team16)
			);
			expect(paired).toBe(false);
		});
		test('powerMatch does not pair Ramona with Chaparral in R4 (HighLow)', () => {
			const priorHistory = F.historyThrough(3);
			const result = powerMatch('HighLow', rankedAfterR3, priorHistory, F.empty());
			const paired = result.pairings.some(
				(p) =>
					(p.prosecutionTeam === F.team16 && p.defenseTeam === F.team22) ||
					(p.prosecutionTeam === F.team22 && p.defenseTeam === F.team16)
			);
			expect(paired).toBe(false);
		});
	});
});
