import { describe, expect, test } from 'vitest'
import { empty, fromRecords, hasPlayed, sideHistory, toRecords } from './matchHistory'
import { powerMatch, type PowerMatchResult } from './powerMatch'
import * as F from './powerMatchFixtures'

function pairedTeamNumbers(result: PowerMatchResult<F.Team>): number[] {
	return result.pairings.flatMap((p) => [p.prosecutionTeam.number, p.defenseTeam.number])
}

const rt = F.rankedTeam

// R2: Winners (1-0): 1,2,4,8,9,12,13,15,16,20,22,25,27
//     Losers (0-1): 3,5,6,10,11,14,17,19,21,23,24,26,28
const rankedAfterR1 = [
	rt(F.team01, 1, 0, 1), rt(F.team02, 1, 0, 2), rt(F.team04, 1, 0, 3),
	rt(F.team08, 1, 0, 4), rt(F.team09, 1, 0, 5), rt(F.team12, 1, 0, 6),
	rt(F.team13, 1, 0, 7), rt(F.team15, 1, 0, 8), rt(F.team16, 1, 0, 9),
	rt(F.team20, 1, 0, 10), rt(F.team22, 1, 0, 11), rt(F.team25, 1, 0, 12),
	rt(F.team27, 1, 0, 13),
	rt(F.team03, 0, 1, 1), rt(F.team05, 0, 1, 2), rt(F.team06, 0, 1, 3),
	rt(F.team10, 0, 1, 4), rt(F.team11, 0, 1, 5), rt(F.team14, 0, 1, 6),
	rt(F.team17, 0, 1, 7), rt(F.team19, 0, 1, 8), rt(F.team21, 0, 1, 9),
	rt(F.team23, 0, 1, 10), rt(F.team24, 0, 1, 11), rt(F.team26, 0, 1, 12),
	rt(F.team28, 0, 1, 13),
]

// R4: 3-0: 1,9,12,13 / 2-1: 2,5,10,15,16,20,22,25,27 / 1-2: 4,6,8,11,19,21,23,26,28 / 0-3: 3,14,17,24
const rankedAfterR3 = [
	rt(F.team01, 3, 0, 1), rt(F.team09, 3, 0, 2), rt(F.team12, 3, 0, 3), rt(F.team13, 3, 0, 4),
	rt(F.team02, 2, 1, 1), rt(F.team05, 2, 1, 2), rt(F.team10, 2, 1, 3),
	rt(F.team15, 2, 1, 4), rt(F.team16, 2, 1, 5), rt(F.team20, 2, 1, 6),
	rt(F.team22, 2, 1, 7), rt(F.team25, 2, 1, 8), rt(F.team27, 2, 1, 9),
	rt(F.team04, 1, 2, 1), rt(F.team06, 1, 2, 2), rt(F.team08, 1, 2, 3),
	rt(F.team11, 1, 2, 4), rt(F.team19, 1, 2, 5), rt(F.team21, 1, 2, 6),
	rt(F.team23, 1, 2, 7), rt(F.team26, 1, 2, 8), rt(F.team28, 1, 2, 9),
	rt(F.team03, 0, 3, 1), rt(F.team14, 0, 3, 2), rt(F.team17, 0, 3, 3), rt(F.team24, 0, 3, 4),
]

describe('PowerMatch', () => {
	describe('structural invariants', () => {
		describe('R2 pairings', () => {
			const result = powerMatch('HighHigh', rankedAfterR1, F.round1History, empty())

			test('every team appears exactly once', () => {
				const keys = pairedTeamNumbers(result).sort((a, b) => a - b)
				const expectedKeys = F.allTeams.map((t) => t.number).sort((a, b) => a - b)
				expect(keys).toEqual(expectedKeys)
			})
			test('produces 13 pairings for 26 teams', () => {
				expect(result.pairings.length).toBe(13)
			})
			test('no rematches against R1 opponents', () => {
				const hasRematch = result.pairings.some((p) =>
					hasPlayed(F.round1History, p.prosecutionTeam, p.defenseTeam)
				)
				expect(hasRematch).toBe(false)
			})
			test('no team plays same side 3+ times', () => {
				const allHistory = fromRecords([
					...toRecords(F.round1History),
					...result.pairings.map((p) => ({ prosecution: p.prosecutionTeam, defense: p.defenseTeam })),
				])
				const sideViolation = F.allTeams.some((team) => {
					const sides = sideHistory(allHistory, team)
					return sides.prosecution >= 3 || sides.defense >= 3
				})
				expect(sideViolation).toBe(false)
			})
			test('side switching: R1 P plays R2 D', () => {
				const r1ProsecutionNums = toRecords(F.round1History).map((r) => r.prosecution.number)
				const violations = result.pairings.filter((p) =>
					r1ProsecutionNums.includes(p.prosecutionTeam.number)
				)
				expect(violations.length).toBe(0)
			})
		})

		describe('R4 pairings', () => {
			const priorHistory = F.historyThrough(3)
			const result = powerMatch('HighHigh', rankedAfterR3, priorHistory, empty())

			test('every team appears exactly once', () => {
				const keys = pairedTeamNumbers(result).sort((a, b) => a - b)
				const expectedKeys = F.allTeams.map((t) => t.number).sort((a, b) => a - b)
				expect(keys).toEqual(expectedKeys)
			})
			test('produces 13 pairings', () => {
				expect(result.pairings.length).toBe(13)
			})
			test('no rematches against R1-R3 opponents', () => {
				const hasRematch = result.pairings.some((p) =>
					hasPlayed(priorHistory, p.prosecutionTeam, p.defenseTeam)
				)
				expect(hasRematch).toBe(false)
			})
			test('side switching: R3 P plays R4 D', () => {
				const r3ProsecutionNums = toRecords(F.round3History).map((r) => r.prosecution.number)
				const violations = result.pairings.filter((p) =>
					r3ProsecutionNums.includes(p.prosecutionTeam.number)
				)
				expect(violations.length).toBe(0)
			})
			test('no team plays same side 3+ times', () => {
				const allHistory = fromRecords([
					...toRecords(priorHistory),
					...result.pairings.map((p) => ({ prosecution: p.prosecutionTeam, defense: p.defenseTeam })),
				])
				const sideViolation = F.allTeams.some((team) => {
					const sides = sideHistory(allHistory, team)
					return sides.prosecution >= 3 || sides.defense >= 3
				})
				expect(sideViolation).toBe(false)
			})
		})
	})

	describe('cross-bracket strategy', () => {
		test('HighHigh and HighLow produce different pairings for R4', () => {
			const priorHistory = F.historyThrough(3)
			const highHigh = powerMatch('HighHigh', rankedAfterR3, priorHistory, empty())
			const highLow = powerMatch('HighLow', rankedAfterR3, priorHistory, empty())
			const hhKeys = highHigh.pairings.map((p) => [p.prosecutionTeam.number, p.defenseTeam.number])
			const hlKeys = highLow.pairings.map((p) => [p.prosecutionTeam.number, p.defenseTeam.number])
			expect(hhKeys).not.toEqual(hlKeys)
		})
		test('HighLow: no rematches', () => {
			const priorHistory = F.historyThrough(3)
			const result = powerMatch('HighLow', rankedAfterR3, priorHistory, empty())
			const hasRematch = result.pairings.some((p) =>
				hasPlayed(priorHistory, p.prosecutionTeam, p.defenseTeam)
			)
			expect(hasRematch).toBe(false)
		})
		test('HighLow: every team appears exactly once', () => {
			const priorHistory = F.historyThrough(3)
			const result = powerMatch('HighLow', rankedAfterR3, priorHistory, empty())
			const keys = pairedTeamNumbers(result).sort((a, b) => a - b)
			const expectedKeys = F.allTeams.map((t) => t.number).sort((a, b) => a - b)
			expect(keys).toEqual(expectedKeys)
		})
	})

	describe('rematch avoidance', () => {
		test('avoids rematch even when greedy choice would cause one', () => {
			const teamA = F.makeTeam(90, 'Team A')
			const teamB = F.makeTeam(91, 'Team B')
			const teamC = F.makeTeam(92, 'Team C')
			const teamD = F.makeTeam(93, 'Team D')
			const priorHistory = fromRecords([
				{ prosecution: teamA, defense: teamD },
				{ prosecution: teamB, defense: teamC },
			])
			const ranked = [
				{ team: teamA, wins: 1, losses: 0, rank: 1 },
				{ team: teamB, wins: 1, losses: 0, rank: 2 },
				{ team: teamC, wins: 0, losses: 1, rank: 1 },
				{ team: teamD, wins: 0, losses: 1, rank: 2 },
			]
			const result = powerMatch('HighHigh', ranked, priorHistory, empty())
			expect(result.pairings.length).toBe(2)
			expect(
				result.pairings.some((p) => hasPlayed(priorHistory, p.prosecutionTeam, p.defenseTeam))
			).toBe(false)
		})
		test('avoids rematch with 6 teams and constrained history', () => {
			const teamA = F.makeTeam(80, 'Team A')
			const teamB = F.makeTeam(81, 'Team B')
			const teamC = F.makeTeam(82, 'Team C')
			const teamD = F.makeTeam(83, 'Team D')
			const teamE = F.makeTeam(84, 'Team E')
			const teamF = F.makeTeam(85, 'Team F')
			const priorHistory = fromRecords([
				{ prosecution: teamA, defense: teamB },
				{ prosecution: teamC, defense: teamD },
				{ prosecution: teamE, defense: teamF },
			])
			const ranked = [
				{ team: teamA, wins: 1, losses: 0, rank: 1 },
				{ team: teamC, wins: 1, losses: 0, rank: 2 },
				{ team: teamE, wins: 1, losses: 0, rank: 3 },
				{ team: teamB, wins: 0, losses: 1, rank: 1 },
				{ team: teamD, wins: 0, losses: 1, rank: 2 },
				{ team: teamF, wins: 0, losses: 1, rank: 3 },
			]
			const result = powerMatch('HighHigh', ranked, priorHistory, empty())
			expect(result.pairings.length).toBe(3)
			expect(
				result.pairings.some((p) => hasPlayed(priorHistory, p.prosecutionTeam, p.defenseTeam))
			).toBe(false)
		})
	})
})
