import { describe, expect, test } from 'vitest'
import { bracket, higherSeed, lowerSeed } from './elimBracket'
import { meetingHistory } from './elimSideRules'

type Team = { id: number; name: string }

function makeTeam(num: number): Team {
	return { id: num, name: `Team ${num}` }
}

const eightTeams: Team[] = Array.from({ length: 8 }, (_, i) => makeTeam(i + 1))

describe('ElimBracket', () => {
	describe('bracket', () => {
		test('8 teams produces Ok with 4 matchups', () => {
			const result = bracket(eightTeams)
			expect(result.ok).toBe(true)
			if (result.ok) expect(result.value).toHaveLength(4)
		})

		test('first matchup: seed 1 vs seed 8', () => {
			const result = bracket(eightTeams)
			expect(result.ok).toBe(true)
			if (!result.ok) return
			const m = result.value[0]
			expect(higherSeed(m).id).toBe(1)
			expect(lowerSeed(m).id).toBe(8)
		})

		test('second matchup: seed 2 vs seed 7', () => {
			const result = bracket(eightTeams)
			expect(result.ok).toBe(true)
			if (!result.ok) return
			const m = result.value[1]
			expect(higherSeed(m).id).toBe(2)
			expect(lowerSeed(m).id).toBe(7)
		})

		test('third matchup: seed 3 vs seed 6', () => {
			const result = bracket(eightTeams)
			expect(result.ok).toBe(true)
			if (!result.ok) return
			const m = result.value[2]
			expect(higherSeed(m).id).toBe(3)
			expect(lowerSeed(m).id).toBe(6)
		})

		test('fourth matchup: seed 4 vs seed 5', () => {
			const result = bracket(eightTeams)
			expect(result.ok).toBe(true)
			if (!result.ok) return
			const m = result.value[3]
			expect(higherSeed(m).id).toBe(4)
			expect(lowerSeed(m).id).toBe(5)
		})

		test('higherSeed accessor returns correct teams', () => {
			const result = bracket(eightTeams)
			expect(result.ok).toBe(true)
			if (!result.ok) return
			expect(result.value.map((m) => higherSeed(m).id)).toEqual([1, 2, 3, 4])
		})

		test('lowerSeed accessor returns correct teams', () => {
			const result = bracket(eightTeams)
			expect(result.ok).toBe(true)
			if (!result.ok) return
			expect(result.value.map((m) => lowerSeed(m).id)).toEqual([8, 7, 6, 5])
		})

		test('fewer than 8 teams returns Err', () => {
			const result = bracket(Array.from({ length: 7 }, (_, i) => makeTeam(i + 1)))
			expect(result.ok).toBe(false)
		})

		test('more than 8 teams returns Err', () => {
			const result = bracket(Array.from({ length: 9 }, (_, i) => makeTeam(i + 1)))
			expect(result.ok).toBe(false)
		})

		test('empty list returns Err', () => {
			const result = bracket([])
			expect(result.ok).toBe(false)
		})
	})

	describe('integration with ElimSideRules', () => {
		test('bracket matchups feed into meetingHistory', () => {
			const result = bracket(eightTeams)
			expect(result.ok).toBe(true)
			if (!result.ok) return
			const m = result.value[0]
			const history = meetingHistory(higherSeed(m), lowerSeed(m), [], 'Prosecution')
			expect(history).toEqual({ kind: 'FirstMeeting', mostRecentSide: 'Prosecution' })
		})
	})
})
